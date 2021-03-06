#' @title Create a `ggplot` directly from an object through an S3 method
#'
#' @description S3 method for creating plots directly from objects using `ggplot2`, similar to base plot function.
#'     The default method is base::plot.
#'     
#' @author Steven Haesendonckx
#' 
#' @seealso \code{\link[ggplot2]{ggplot}}
#' 
#' @param x object to be passed on to the method
#' @param ... other arguments passed on to the method
#'  
#' @rdname vr_plot
#' 
#' @export

vr_plot <- function(x, ...){
  UseMethod("vr_plot")
} 

#' @rdname vr_plot
#' @method vr_plot default
#' @export

vr_plot.default <- function(x, ...){
  base::plot(x)
}

#' @param survfit_object Object of class `survfit`
#' @param y_label \code{character} Label for the y-axis. When not specified, the default will do a proposal, depending on the `fun` argument.
#' @param x_label \code{character} Label for the x-asis. When not specified, the algorithm will look for "PARAM" information inside the list structure of the `survfit` object.
#'   Note that this information is automatically added when using visR::vr_KM_est and when the input data has the variable "PARAM". If no "PARAM" information is available
#'   "time" is used as label.
#' @param x_units Unit to be added to the x_label (x_label (x_unit)). Default is NULL.
#' @param x_ticks Ticks for the x-axis. When not specified, the default will do a proposal. 
#' @param y_ticks Ticks for the y-axis. When not specified, the default will do a proposal based on the `fun` argument.
#' @param fun Arbitrary function defining a transformation of the survival curve. This argument will also influence the y_ticks and y_label if not specified. 
#'    \itemize{
#'      \item{"surv": survival curve on the probability scale. The default y label will state "Survival probability".}
#'      \item{"log": log survival curve. The default y label will state "log(Survival probability)".}
#'      \item{"event": empirical CDF f(y) = 1-y. The default y label will state "Failure probability".}
#'      \item{"cloglog": complimentary log-log survival f(y) = log(-log(y)). The default y label will state "log(-log(Survival probability))".}
#'      \item{"pct": survival curve, expressed as percentage. The default y label will state "Survival probability".}
#'      \item{"logpct": log survival curve, expressed as percentage. The default y label will state "log(Survival probability".}
#'      \item{"cumhaz": MLE estimate of the cumulative hazard f(y) = -log(y). The default y label will state "cumulative hazard".}
#'    }
#' @param legend_position Specifies the legend position in the plot. Character values allowed are "top" "left" "bottom" "right". Numeric coordinates are also allowed.
#'   Default is "right".
#' 
#' 
#' @examples
#' library(survival)
#' library(dplyr)
#' library(tidyr)
#' library(ggplot2)
#' 
#' survfit_object <- vr_KM_est(data = adtte, strata = "TRTP")
#'
#' ## Plot survival probability
#' vr_plot(survfit_object = survfit_object, fun = "surv")
#' vr_plot(survfit_object, fun = "pct")
#' 
#' ## Plot cumulative hazard
#' vr_plot(survfit_object, fun = "cloglog")
#'  
#' @return Object of class \code{ggplot}  \code{ggsurvplot}.
#'  
#' @rdname vr_plot
#' @method vr_plot survfit
#' @export
#
vr_plot.survfit <- function(
  survfit_object = NULL
 ,y_label = NULL
 ,x_label = NULL
 ,x_units = NULL
 ,x_ticks = NULL
 ,y_ticks = NULL
 ,fun = "surv"
 ,legend_position = "right"
 ){
  
  #### Input validation ####
  
  if (!inherits(survfit_object, "survfit")) stop("survfit object is not of class `survfit`")
  if (is.character(legend_position) && ! legend_position %in% c("top", "bottom", "right", "left", "none")){
    stop("Invalid legend position given.")
  } else if (is.numeric(legend_position) && length(legend_position) != 2) {
    stop("Invalid legend position coordinates given.")
  }
  
  #### FUN ####
  
  if (is.character(fun)){
    .transfun <- base::switch(
      fun,
      surv = function(y) y,
      log = function(y) log(y),
      event = function(y) 1 - y,
      cloglog = function(y) log(-log(y)),
      pct = function(y) y * 100,
      logpct = function(y) log(y *100),
      cumhaz = function(y) -log(y), ## survfit object contains an estimate for Cumhaz and SE based on Nelson-Aalen with or without correction for ties
      stop("Unrecognized fun argument")
    )
  } else if (is.function(fun)) {
     fun
  } else {
    stop("Error in vr_plot: fun should be a character or a function.")
  }

  #### Y-label ####
  
  if (is.null(y_label) & is.character(fun)){
    y_label <- base::switch(
      fun,
      surv = "Survival probability",
      log = "log(Survival probability)",
      event = "Failure probability",
      cloglog = "log(-log(Survival probability))",
      pct = "Survival probability (%)",
      logpct = "log(Survival probability (%))",
      cumhaz = "cumulative hazard",
      stop("Unrecognized fun argument")
    )
  } else if (is.null(y_label) & is.function(fun)) {
    stop("Error in vr_plot: No Y label defined. No default is available when `fun` is a function.")
  }  

  ### Extended tidy of survfit class + transformation ####
  
  correctme <- NULL
  tidy_object <- tidyme.survfit(survfit_object)
  if ("surv" %in% colnames(tidy_object)) {
    tidy_object[["est"]] <- .transfun(tidy_object[["surv"]])
    correctme <- c(correctme,"est")
  }
  if (base::all(c("upper", "lower") %in% colnames(tidy_object))) {
    tidy_object[["est.upper"]] <- .transfun(tidy_object[["upper"]])
    tidy_object[["est.lower"]] <- .transfun(tidy_object[["lower"]])
    correctme <- c(correctme,"est.lower", "est.upper")
  } 

  #### Adjust -Inf to minimal value ####
  
  tidy_object[ , correctme] <- sapply(tidy_object[ , correctme],
                                      FUN = function(x) {
                                              x[which(x == -Inf)] <- min(x[which(x != -Inf)], na.rm = TRUE)
                                              return(x)
                                            } 
  )
  
  ymin = min(sapply(tidy_object[ , correctme], function(x) min(x[which(x != -Inf)], na.rm = TRUE)), na.rm = TRUE)
  ymax = max(sapply(tidy_object[ , correctme], function(x) max(x[which(x != -Inf)], na.rm = TRUE)), na.rm = TRUE)

  if (fun == "cloglog") {
      
      if (nrow(tidy_object[tidy_object$est == "-Inf",]) > 0) {
          
          warning("NAs introduced by y-axis transformation.\n")
          
      } 
      
      tidy_object = tidy_object[tidy_object$est != "-Inf",]
      
  }
    
  #### Obtain alternatives for X-axis ####
  
  if (is.null(x_label)){
    if ("PARAM" %in% names(survfit_object)) x_label = survfit_object[["PARAM"]]
    if (! "PARAM" %in% names(survfit_object)) x_label = "time"
    if (!is.null(x_units)) x_label = paste0(x_label, " (", x_units, ")")
  }
  if (is.null(x_ticks)) x_ticks = pretty(survfit_object$time, 10)
  
  #### Obtain alternatives for Y-axis ####
  
  if (is.null(y_ticks) & is.character(fun)){
    y_ticks <- base::switch(
      fun,
      surv = pretty(c(0,1), 5),
      log =  pretty(round(c(ymin,ymax), 0), 5),
      event = pretty(c(0,1), 5),
      cloglog = pretty(round(c(ymin,ymax), 0), 5),
      pct = pretty(c(0,100), 5),
      logpct = pretty(c(0,5), 5),
      cumhaz =  pretty(round(c(ymin,ymax), 0), 5),
      stop("Unrecognized fun argument")
    )
  } else if (is.null(y_label) & is.function(fun)) {
    stop("Error in vr_plot: No Y label defined. No default is available when `fun` is a function.")
  }  

  #### Plotit ####
  
  yscaleFUN <- function(x) sprintf("%.2f", x)
  
  gg <- ggplot2::ggplot(tidy_object, aes(x = time, group = strata)) +
    ggplot2::geom_step(aes(y = est, col = strata)) + 
    ggsci::scale_color_nejm() + 
    ggsci::scale_fill_nejm() + 
    ggplot2::scale_x_continuous(name = paste0("\n", x_label),
                                breaks = x_ticks,
                                limits = c(min(x_ticks), max(x_ticks))) +
    ggplot2::scale_y_continuous(name = paste0(y_label, "\n"),
                                breaks = y_ticks,
                                labels = yscaleFUN,
                                limits = c(min(y_ticks), max(y_ticks))) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = legend_position) +
    ggplot2::guides(color=guide_legend(override.aes=list(fill=NA))) +
    NULL
  
  class(gg) <- append(class(gg), "ggsurvfit")
  
  return(gg)
}
