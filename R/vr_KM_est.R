#' @title Wrapper for Kaplan Meier analysis for an ADaM Basic Data Structure (BDS) for Time-to-Event analysis
#'  
#' @description This function is a wrapper around \code{survival::survfit.formula} to perform a Kaplan-Meier analysis,
#'    based on the expected ADaM Basic Data Structure (BDS) for Time-to-Event analysis and assuming right-censored data.
#'    The function expects that the data has been filtered on the PARAM/PARAMCD of interest.
#'    Alternatively, PARAM/PARAMCD can be used in the \code{strata} argument. \cr
#'    The result is an object of class \code{survfit} which can be used in downstream functions and methods that rely on the \code{survfit} class.
#'    By default:
#'    \itemize{
#'      \item{The Kaplan Meier estimate is estimated directly (stype = 1).}
#'      \item{The cumulative hazard is estimated using the Nelson-Aalen estimator (ctype = 1): H.tilde = cumsum(x$n.event/x$n.risk).
#'      The MLE (H.hat(t) = -log(S.hat(t))) can't be requested.}
#'      \item{A two-sided pointwise 0.95 confidence interval is estimated using a log transformation (conf.type = "log").}
#'    }
#'
#' @author Steven Haesendonckx
#' 
#' @seealso \code{\link[survival]{survfit.formula} \link[survival]{survfitCI}}
#' 
#' @param data The name of the ADaM Basic Data Structure (BDS) for Time-to-Event analysis eg ADTTE. Rows in which AVAL or CNSR contain NA, are removed during analysis. 
#' @param strata Character vector, representing the strata for Time-to-Event analysis eg TRT01P. When NULL, an overall analysis is performed.
#'   Default is NULL.
#' @param ... additional arguments passed on to the ellipsis of the call \code{survival::survfit.formula(data = data, formula = Surv(AVAL, 1-CNSR) ~ strata), ...)} .
#' Use \code{?survival::survfit.formula} and \code{?survival::survfitCI} for more information.    
#'
#' @return survfit object, extended by elements PARAM/PARAMCD, ready for downstream processing in estimation or visualization functions and methods.
#' 
#' @references \url{https://https://github.com/therneau/survival}
#' 
#' @export
#'
#' @examples
#' library(survival)
#' library(dplyr)
#' library(tidyr)
#' 
#' ## No stratification
#' vr_KM_est(data = adtte)
#' 
#' ## Stratified Kaplan-Meier analysis by `TRTP`
#' vr_KM_est(data = adtte, strata = "TRTP")
#' 
#' ## Stratified Kaplan-Meier analysis by `TRTP` and `SEX` 
#' vr_KM_est(data = adtte, strata = c("TRTP", "SEX"))
#' 
#' ## Stratification with one level
#' vr_KM_est(data = adtte, strata = "PARAMCD")
#' 
#' ## Analysis on subset of adtte
#' vr_KM_est(data = adtte[adtte$SEX == "F", ])
#' 
#' ## Modify the default analysis by using the ellipsis
#' #vr_KM_est(data = adtte, strata = NULL, type = "kaplan-meier", conf.int = F, timefix = TRUE)
#' vr_KM_est(data = adtte, strata = NULL, type = "kaplan-meier", conf.int = FALSE, timefix = TRUE)

vr_KM_est <- function(
   data = NULL
  ,strata = NULL
  ,...
){
  
  #### Capture input + identify ... for updating $call ####
  Call <- as.list(match.call())
  dots <- list(...)
  dfExpr <- Call[["data"]]

  #### Get actual data name as symbol ####
    ## Magrittre pipe returns "." which inactivates recalls to survfit in downstream functions
    ## map passes .x as Call$data
    ## df: catch expressions that represent base R subsets

  if (base::length(base::deparse(Call[["data"]])) == 1 && base::deparse(Call[["data"]]) %in% c(".", ".x")){
    Call[["data"]] <- as.symbol(the_lhs())
    df <- as.character(Call[["data"]])
  } else {
    df <- as.character(sub("\\[.*$", "", deparse(dfExpr))[1])
  } 

  #### Validate input ####
  reqcols <- c(strata, "CNSR", "AVAL")
  
  if (! base::exists(df)){
    stop(paste0("Data ", df, " not found."))
  }
  
  if (! all(reqcols %in% colnames(data))){
    stop(paste0("Following columns are missing from `data`: ", paste(setdiff(reqcols, colnames(data)), collapse = " "), "."))
  }
  
  if (! is.numeric(data[["AVAL"]])){
    stop("Analysis variable, AVAL, is not numeric.")
  }
  
  if (! is.numeric(data[["CNSR"]])){
    stop("Censor variable, CNSR, is not numeric.")
  }
  
  #### Ensure strata is present ####
  if (is.null(strata)){
    main <- "1"
  } else {
    main <- paste(strata, collapse = " + ")
  }
  
  #### Ensure to have data frame and remove missing aval, strata ####
  data <- as.data.frame(data)%>%
    tidyr::drop_na(AVAL, CNSR)
  
  if (!is.null(strata)){
    data <- data%>%
      tidyr::drop_na(any_of({{strata}}))
  }

  #### Calculate survival and add starting point (time 0) to the survfit object ####
    ## Reverse censoring: see ADaM guidelines versus R survival KM analysis
  
  formula <- stats::as.formula(glue::glue("Surv(AVAL, 1-CNSR) ~ {main}"))
  
  survfit_object <- survival::survfit(
    formula, data = data, ...
  )

  survfit_object <- survival::survfit0(
    survfit_object, start.time = 0
  )
  
  #### Update call statement with original information and dots, similar as update.default method ####
  survfit_object$call[["formula"]] <- formula
  survfit_object$call[["data"]] <- Call$data
  if (length(dots) > 0){
    names(survfit_object$call)
    names(dots)
    for (i in seq_along(dots)){
      survfit_object$call[[names(dots)[i]]] <- unlist(dots[i], use.names = F)
    }
  }
  
  if ("PARAM" %in% colnames(data) && length(setdiff(c("PARAMCD", "PARAM"), strata)) == 2){
    # we expect only one unique value => catch mistakes
    survfit_object[["PARAM"]] <- paste(unique(data[["PARAM"]]), collapse = ", ")
  }
    
  if ("PARAMCD" %in% colnames(data) && length(setdiff(c("PARAMCD", "PARAM"), strata)) == 2){
    # we expect only one unique value => catch mistakes
    survfit_object[["PARAMCD"]] <- paste(unique(data[["PARAMCD"]]), collapse = ", ")
  } 
  
  #### No strata: Create an artificial one for compatibility with downstream processing ####
  if (is.null(survfit_object$strata)){
    survfit_object$strata <- as.vector(length(survfit_object$time))
    
    if (main == "1"){
      # overall analysis
      attr(survfit_object$strata, "names") <- "Overall"
    } else {
      # ~ x with One level in variable present
      attr(survfit_object$strata, "names") <- as.character(data[1, main])
    }
  }
  
  #### Return ####
  return(survfit_object)
}