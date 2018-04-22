# elbr: Tools for Analyzing AWS ELB Logs

[![Build Status](https://travis-ci.org/nealrichardson/elbr.png?branch=master)](https://travis-ci.org/nealrichardson/elbr)  [![codecov](https://codecov.io/gh/nealrichardson/elbr/branch/master/graph/badge.svg)](https://codecov.io/gh/nealrichardson/elbr) [![Build status](https://ci.appveyor.com/api/projects/status/g72a7u4bu7sjwm26/branch/master?svg=true)](https://ci.appveyor.com/project/nealrichardson/elbr/branch/master) [![cran](https://www.r-pkg.org/badges/version-last-release/elbr)](https://cran.r-project.org/package=elbr)

Amazon Web Services' Elastic Load Balancer (ELB) emits log files in a defined, space-delimited text file format. This package provides tools for reading and exploring those logs in R. There is a file reader, `read_elb()`, which reads single files, and `ELBLog()`, a `dplyr` backend that enables you to work with recursive directories of many log files, as ELB writes them out, without having to think about all of the individual files. All functions are designed to be as fast and efficient as possible, only reading in and stacking together the rows and columns of data you need. 

## Installing

<!-- `elbr` can be installed from CRAN with

    install.packages("elbr") -->

`elbr` is not (yet) on CRAN. The pre-release version of the package can be pulled from GitHub using the [devtools](https://github.com/r-lib/devtools) package:

    # install.packages("devtools")
    devtools::install_github("nealrichardson/elbr")

## Using

If you have a single log file you want to read, you can call `read_elb()` directly on it. The function uses the `readr` package for fast text file reading. To make it go even faster, you can specify selected `"columns"` by name that you want to keep, and you can provide a `"line_filter"` to select rows by raw text pattern.

```r
df <- read_elb(
    "path/to/logfile.log",
    columns=c("timestamp", "elb_status_code", "request")
)
```

If you want to scan log files across a directory or tree of directories, you can use the `ELBLog()` object to set up a "connection" to the file system and use `dplyr` methods on it, treating the file system as a single database rather than bunches of files.

```r
df <- ELBLog() %>%
    select(timestamp, elb_status_code, request) %>%
    filter(elb_status_code >= 400) %>%
    collect()
)
```

You can also specify a `line_filter()` in the pipeline to take advantage of its fast filtering.

## For developers

The repository includes a Makefile to facilitate some common tasks from the command line, if you're into that sort of thing.

### Running tests

`$ make test`. Requires the [testthat](http://testthat.r-lib.org) package. You can also specify a specific test file or files to run by adding a "file=" argument, like `$ make test file=read`. `testthat::test_package()` will do a regular-expression pattern match within the file names.

### Updating documentation

`$ make doc`. Requires the [roxygen2](https://github.com/klutometis/roxygen) package.
