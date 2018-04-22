#' Load an ELB log file
#'
#' @param file A file name or connection. See [readr::read_delim()]
#' @param columns Optional character vector to specify a subset of columns to
#' import. If you know you only want to work with a few columns, it is faster
#' to specify it at read time rather than filtering after. Unlike the behavior
#' of `read_delim()`'s `col_names`, these may be specified out of order, and the
#' `data.frame` you get back will be in the order you specify.
#'
#' Default is to return everything.
#' @param ... Additional arguments passed to [readr::read_delim()]
#' @param line_filter A string pattern or regular expression to pass to the
#' shell command `egrep`. This enables you to filter down the rows of the log
#' file to read in much more quickly than reading the whole file into R and then
#' subsetting the data in memory---if you know a good filtering string to use.
#' It is best only to use this parameter if you're looking for a relatively
#' uncommon pattern; if your `line_filter` matches all lines, it will be slower
#' than omitting it.
#' @return A tibble.
#' @export
#' @importFrom readr read_delim
read_elb <- function (file,
                    columns=c("timestamp", "elb", "client_port", "backend_port",
                            "request_processing_time", "backend_processing_time",
                            "response_processing_time", "elb_status_code",
                            "backend_status_code", "received_bytes", "sent_bytes",
                            "request", "user_agent", "ssl_cipher", "ssl_protocol"),
                    line_filter=NULL,
                    ...) {

    ## Allow specifying a selection of columns. Fill in "col_types" with "-"
    all_cols <- eval(formals(sys.function())[["columns"]])
    col_types <- unlist(strsplit("Tcccdddiiiicccc", ""))
    columns <- match.arg(columns, several.ok=TRUE)
    keepcols <- all_cols %in% columns
    col_types[!keepcols] <- "-"

    if (!is.null(line_filter)) {
        ## Shell out to egrep
        ## If there are no matches, egrep returns status 1, which creates
        ## a warning in R (with system2 when stdout=TRUE)
        file <- suppressWarnings(
            system2("egrep", c(shQuote(line_filter), file), stdout=TRUE)
        )
        nmatches <- length(file)
        ## Concatenate
        file <- paste(file, collapse="\n")
        if (nmatches < 2) {
            ## Append a newline so that readr recognizes this as literal data
            file <- paste0(file, "\n")
        }
    }
    out <- read_delim(
        file,
        col_names=all_cols[keepcols],
        col_types=paste(col_types, collapse=""),
        delim=" ",
        escape_backslash=TRUE,
        escape_double=FALSE,
        na=c("", "-1"),
        ...
    )
    if (!identical(names(out), columns)) {
        ## Reorder
        out <- out[, columns]
    }
    return(out)
}

#' Split the 'request' into verb, url, protocol
#'
#' @param x Character vector, the "request" column from an ELB data.frame
#' @return A `data.frame` with three columns: "request_verb", "request_url",
#' and "request_protocol".
#' @export
parse_request <- function (x) {
    ## Split the 'request' into verb, url, protocol
    reqs <- as.data.frame(matrix(unlist(strsplit(x, " ")), ncol=3, byrow=TRUE),
        stringsAsFactors=FALSE)
    names(reqs) <- c("request_verb", "request_url", "request_protocol")
    return(reqs)
}
