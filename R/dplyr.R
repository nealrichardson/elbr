#' Interface to a set of ELB log files
#'
#' AWS ELB logs are stored in a series of paths separated for each year, then
#' month, then day, with many files per day in the lowest level directories.
#' Objects of class `ELBLog` contain information about which log files to read
#' in, and methods such as [select()], [filter()], [summarize()], and
#' [collect()] are defined to enable you to work with this log data as if it
#' were a single `data.frame` in memory, even though constructing that dataset
#' would be too slow or perhaps impossible due to resource constraints.
#'
#' @param start_date A `Date` or character in format "YYYY-MM-DD" representing
#' a starting date for log files to consider. Default is `NULL`, meaning that
#' all log files found in `path` will be considered. Specifying a `start_date`
#' when appropriate can greatly speed up analyses by skipping files that are
#' out of the range of interest.
#' @param end_date See `start_date`. Default for `end_date` is the value of
#' `start_date`, i.e. if a `start_date` is given and no `end_date` is provided,
#' only that day's log files will be considered.
#' @param path character file path indicating where the ELB logs are contained.
#' Default is the current working directory, unless `options(elbr.dir)` is set.
#' @return An S3-class 'ELBLog' object.
#' @export
#' @examples
#' \dontrun{
#' ELBLog("2017-12-15", "2018-01-15") %>%
#'     select(elb_status_code, request) %>%
#'     filter(elb_status_code == 200) %>%
#'     collect()
#' }
ELBLog <- function (start_date=NULL, end_date=start_date, path=getOption("elbr.dir", ".")) {
    structure(list(
        select=list(),
        filter=list(),
        start_date=start_date,
        end_date=end_date,
        path=path
    ), class="ELBLog")
}

#' @importFrom dplyr select
#' @importFrom rlang quos
#' @export
select.ELBLog <- function (.data, ...) {
    .data$select <- c(.data$select, list(quos(...)))
    return(.data)
}

#' @importFrom dplyr filter
#' @export
filter.ELBLog <- function (.data, ...) {
    .data$filter <- c(.data$filter, list(quos(...)))
    return(.data)
}

#' ELBLog method for setting a line filter
#'
#' This function lets you use the `line_filter` parameter of [read_elb()] when
#' querying over many files.
#' @param .data The `ELBLog` object
#' @param pattern A string pattern or regular expression to pass to the
#' shell command `egrep`. This enables you to filter down the rows of the log
#' file to read in much more quickly than reading the whole file into R and then
#' subsetting the data in memory---if you know a good filtering string to use.
#' It is best only to use this parameter if you're looking for a relatively
#' uncommon pattern; if your `pattern` matches all lines, it will be slower
#' than omitting it.
#' @return `.data` with `pattern` set on it. No I/O happens until you call
#' [collect()] or [summarize()].
#' @export
#' @examples
#' \dontrun{
#' ELBLog() %>%
#'     select(elb_status_code, request) %>%
#'     line_filter(" -1 -1 504 ") %>%
#'     collect()
#' }
line_filter <- function (.data, pattern) {
    UseMethod("line_filter")
}

#' @export
line_filter.default <- function (.data, pattern) {
    stop('"line_filter" is not defined for objects of class ', class(.data)[1],
        call.=FALSE)
}

#' @export
line_filter.ELBLog <- function (.data, pattern) {
    .data$line_filter <- pattern
    return(.data)
}

#' @importFrom dplyr collect
#' @importFrom rlang !!!
#' @importFrom tidyselect vars_select
#' @export
collect.ELBLog <- function (x, ...) {
    return(bind_rows(map_elb(x, ...)))
}

map_elb <- function (.data, FUN=NULL, ...) {
    ## Read data from all files, following the select/filter instructions
    if (is.null(FUN)) {
        fn <- function (f) collect_one(f, vars=colnames, filter=.data$filter, lines=.data$line_filter)
    } else {
        fn <- function (f) FUN(collect_one(f, vars=colnames, filter=.data$filter, lines=.data$line_filter), ...)
    }

    colnames <- eval(formals(read_elb)[["columns"]])
    for (q in .data$select) {
        colnames <- vars_select(colnames, !!! q)
    }
    if (is.null(.data$files)) {
        ## is.null check is to be able to poke in select files
        .data$files <- find_log_files(.data$start_date, .data$end_date, .data$path)
    }
    ## To turn off parallel, set options(mc.cores=1); makes it call lapply
    dfs <- parallel::mclapply(.data$files, fn)
    return(dfs)
}

collect_one <- function (file, vars, filter, lines) {
    df <- read_elb(file, columns=vars, line_filter=lines)
    for (f in filter) {
        df <- filter(df, !!! f)
    }
    return(df)
}

#' @importFrom dplyr summarise summarize
#' @export
summarise.ELBLog <- function (.data, ...) {
    ## TODO: map-then-reduce when possible
    return(summarise(collect(.data), ...))
}

summarize2 <- function (.data, ...) {
    fns <- lapply(quos(...), quo_get_function)
    if (all(unlist(fns)) %in% c("sum", "max", "min")) {
        ## We can aggregate these in pieces

    }
}

quo_get_function <- function (x) as.character(rlang::quo_get_expr(x)[[1]])
