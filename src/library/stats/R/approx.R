#  File src/library/stats/R/approx.R
#  Part of the R package, http://www.R-project.org
#
#  Copyright (C) 1995-2012 The R Core Team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  A copy of the GNU General Public License is available at
#  http://www.r-project.org/Licenses/

### approx() and approxfun() are *very similar* -- keep in sync!

## This function is used in approx, approxfun, spline, and splinefun
## to massage the input (x,y) pairs into standard form:
## x values unique and increasing, y values collapsed to match
## (except if ties=="ordered", then not unique)

regularize.values <- function(x, y, ties) {
    x <- xy.coords(x, y) # -> (x,y) numeric of same length
    y <- x$y
    x <- x$x
    if(any(na <- is.na(x) | is.na(y))) {
	ok <- !na
	x <- x[ok]
	y <- y[ok]
    }
    nx <- length(x)
    if (!identical(ties, "ordered")) {
    	o <- order(x)
	x <- x[o]
	y <- y[o]
	if (length(ux <- unique(x)) < nx) {
	    if (missing(ties))
		warning("collapsing to unique 'x' values")
	    # tapply bases its uniqueness judgement on character representations;
	    # we want to use values (PR#14377)
	    y <- as.vector(tapply(y,match(x,x),ties))# as.v: drop dim & dimn.
	    x <- ux
	    stopifnot(length(y) == length(x))# (did happen in 2.9.0-2.11.x)
	}
    }
    list(x=x, y=y)
}

approx <- function(x, y = NULL, xout, method = "linear", n = 50,
		   yleft, yright, rule = 1, f = 0, ties = mean)
{
    method <- pmatch(method, c("linear", "constant"))
    if (is.na(method)) stop("invalid interpolation method")
    stopifnot(is.numeric(rule), (lenR <- length(rule)) >= 1L, lenR <= 2L)
    if(lenR == 1) rule <- rule[c(1,1)]
    x <- regularize.values(x, y, ties) # -> (x,y) numeric of same length
    y <- x$y
    x <- x$x
    nx <- as.integer(length(x))
    if (is.na(nx)) stop("invalid length(x)")
    if (nx <= 1) {
	if(method == 1)# linear
	    stop("need at least two non-NA values to interpolate")
	if(nx == 0) stop("zero non-NA points")
    }

    if (missing(yleft))
	yleft <- if (rule[1L] == 1) NA else y[1L]
    if (missing(yright))
	yright <- if (rule[2L] == 1) NA else y[length(y)]
    stopifnot(length(yleft) == 1L, length(yright) == 1L, length(f) == 1L)
    if (missing(xout)) {
	if (n <= 0) stop("'approx' requires n >= 1")
	xout <- seq.int(x[1L], x[nx], length.out = n)
    }
    x <- as.double(x); y <- as.double(y)
    .Call(C_ApproxTest, x, y, method, f)
    yout <- .Call(C_Approx, x, y, xout, method, yleft, yright, f)
    list(x = xout, y = yout)
}

approxfun <- function(x, y = NULL, method = "linear",
		   yleft, yright, rule = 1, f = 0, ties = mean)
{
    method <- pmatch(method, c("linear", "constant"))
    if (is.na(method)) stop("invalid interpolation method")
    stopifnot(is.numeric(rule), (lenR <- length(rule)) >= 1L, lenR <= 2L)
    if(lenR == 1) rule <- rule[c(1,1)]
    x <- regularize.values(x, y, ties) # -> (x,y) numeric of same length
    y <- x$y
    x <- x$x
    n <- as.integer(length(x))
    if (is.na(n)) stop("invalid length(x)")

    if (n <= 1) {
	if(method == 1)# linear
	    stop("need at least two non-NA values to interpolate")
	if(n == 0) stop("zero non-NA points")
    }
    if (missing(yleft))
	yleft <- if (rule[1L] == 1) NA else y[1L]
    if (missing(yright))
	yright <- if (rule[2L] == 1) NA else y[length(y)]
    force(f)
    stopifnot(length(yleft) == 1L, length(yright) == 1L, length(f) == 1L)
    rm(rule, ties, lenR, n) # we do not need n, but summary.stepfun did.

    ## 1. Test input consistency once
    x <- as.double(x); y <- as.double(y)
    .Call(C_ApproxTest, x, y, method, f)

    ## 2. Create and return function that does not test input validity...
    function(v) .approxfun(x, y, v, method, yleft, yright, f)
}

## avoid capturing internal calls
.approxfun <- function(x, y, v,  method, yleft, yright, f)
    .Call(C_Approx, x, y, v, method, yleft, yright, f)
