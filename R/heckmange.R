#' heckmanGE
#'
#' Optimized Function for fitting the Generalized Heckman Model
#'
#' (original version: package ssmodels. Modified by Rogerio Barbosa)
#'
#' @description
#' Estimates the parameters of the Generalized Heckman model
#'
#' @details
#' The heckmanGE() function fits a generalization of the Heckman sample
#' selection model, allowing sample selection bias and dispersion parameters
#' to depend on covariates.
#' The `heckmanGE()` function fits a generalization of the Heckman sample
#' selection model, and is compatible with robust variance-covariance estimation
#' using packages such as \pkg{sandwich}. In particular, the
#' \code{\link[sandwich]{vcovCL}} function can be used for clustering, which
#' adjusts the standard errors by accounting for intra-cluster correlations in the data.
#'
#' @param selection A formula. Selection equation.
#' @param outcome A formula. Outcome Equation.
#' @param dispersion A right-handed formula. The equation for fitting of the
#' Dispersion Parameter.
#' @param correlation A right-handed formula. The equation for fitting of the
#' Correlation Parameter.
#' @param data A data.frame.
#' @param weights an optional vector of weights to be used in the fitting process.
#' Should be NULL or a numeric vector.
#' @param cluster a variable indicating the clustering of observations, a list
#' (or data.frame) thereof, or a formula specifying which variables from the
#' fitted model should be used. See documentation for sandwich::vcovCL. A formula
#' or list specifying the clusters for robust standard errors. Clustering adjusts
#' the standard errors by accounting for correlations within clusters.
#' @param start   Optional. A numeric vector with the initial values for the
#' parameters.
#' @return
#' A list containing:
#' \describe{
#'   \item{call}{The matched function call.}
#'   \item{coefficients}{Estimated coefficients for the selection, outcome,
#'   dispersion, and correlation equations.}
#'   \item{vcov}{The covariance matrix of the estimated coefficients.}
#'   \item{logLik}{The log-likelihood of the fitted model.}
#'   \item{model.frames}{List of model frames for each equation (selection, outcome,
#'   dispersion, and correlation).}
#'   \item{fitted.values}{Fitted values of the outcome equation.}
#' }
#'
#'
#' @examples
#' data(MEPS2001)
#' selectEq  <- dambexp ~ age + female + educ + blhisp + totchr + ins + income
#' outcomeEq <- lnambx ~ age + female + educ + blhisp + totchr + ins
#' dispersion  <- ~ age + female + totchr + ins
#' correlation  <- ~ age
#' fit <- heckmanGE(selection = selectEq,
#'                  outcome = outcomeEq,
#'                  dispersion = dispersion,
#'                  correlation = correlation,
#'                  data = MEPS2001)
#' summary(fit)
#' @seealso
#' \code{\link[sandwich]{vcovCL}} for computing robust standard errors with clustering.
#' The function is compatible with the \pkg{sandwich} package for estimating
#' heteroskedasticity-consistent and cluster-robust standard errors.
#' This can be useful for adjusting the standard errors when dealing with grouped
#' or clustered data. For more details, see the documentation for
#' \code{\link[sandwich]{vcovCL}}.

#' @importFrom stats complete.cases model.matrix model.response
#' @export
heckmanGE <- function(selection, outcome, dispersion, correlation,
                      data = sys.frame(sys.parent()),
                      weights = NULL,
                      cluster = NULL,
                      start = NULL) {

  # Recovering the function call -----------------------------------------

  mf <- match.call(expand.dots = FALSE)

  # Ensuring we are dealing with complete cases --------------------------

  yS_name    = as.character(selection[[2]])
  yO_name    = as.character(outcome[[2]])
  weight_var = as.character(mf[match(c("weights"), names(mf), 0)])

  # Identifying complete cases - Y variables
  complete_Y_selection          = complete.cases(data[, unique(c(yS_name, all.vars(selection)))])
  complete_Y_outcome_dispersion = complete.cases(data[, unique(c(all.vars(outcome), all.vars(dispersion)))])
  complete_Y_correlation        = complete.cases(data[, all.vars(correlation)])

  # Gathering all variable names mentioned in the function call
  modelvars = unique(c(all.vars(selection),
                       all.vars(outcome),
                       all.vars(dispersion),
                       all.vars(correlation),
                       all.vars(cluster),
                       weight_var))


  # Selecting complete cases
  data <- data[complete_Y_selection & complete_Y_correlation & ((data[[yS_name]] %in% 0) | ((data[[yS_name]] %in% 1) & complete_Y_outcome_dispersion)),
               modelvars]

  # Extracting model matrices --------------------------------------------

  ## Selection Equation ----
  m <- match(c("selection", "data", "subset", "weights"), names(mf), 0)
  mfS <- mf[c(1, m)]
  mfS$drop.unused.levels <- TRUE
  mfS$na.action <- na.pass
  mfS$data <- quote(data)
  mfS[[1]] <- as.name("model.frame")
  names(mfS)[2] <- "formula" # model.frame requires the parameter to be formula
  mfS <- eval(mfS)
  mtS <- terms(mfS)
  XS <- model.matrix(mtS, mfS)
  YS <- model.response(mfS)

  ## Outcome Equation (regression for the mean) ----
  m <- match(c("outcome", "data", "subset", "weights", "offset"), names(mf), 0)
  mfO <- mf[c(1, m)]
  mfO$na.action <- na.pass
  mfO$drop.unused.levels <- TRUE
  mfO$na.action <- na.pass
  mfO$data <- quote(data)
  mfO[[1]] <- as.name("model.frame")
  names(mfO)[2] <- "formula"
  mfO <- eval(mfO)
  mtO <- attr(mfO, "terms")
  XO <- model.matrix(mtO, mfO)
  YO <- model.response(mfO)


  # Dispersion Equations ----
  m <- match(c("dispersion", "data", "subset", "weights", "offset"), names(mf), 0)
  mfD <- mf[c(1, m)]
  mfD$na.action <- na.pass
  mfD$drop.unused.levels <- TRUE
  mfD$na.action <- na.pass
  mfD$data <- quote(data)
  mfD[[1]] <- as.name("model.frame")
  names(mfD)[2] <- "formula"
  mfD <- eval(mfD)
  mtD <- attr(mfD, "terms")
  Msigma <- model.matrix(mtD, mfD)


  # Correlation Equation ----
  m <- match(c("correlation", "data", "subset", "weights", "offset"), names(mf), 0)
  mfC <- mf[c(1, m)]
  mfC$na.action <- na.pass
  mfC$drop.unused.levels <- TRUE
  mfC$na.action <- na.pass
  mfC$data <- quote(data)
  mfC[[1]] <- as.name("model.frame")
  names(mfC)[2] <- "formula"
  mfC <- eval(mfC)
  mtC <- attr(mfC, "terms")
  Mrho <- model.matrix(mtC, mfC)

  # Sampling weights ----
  w <- as.vector(model.weights(mfS))
  if (!is.null(w) && !is.numeric(w))
    stop("'weights' must be a numeric vector")
  if(is.null(w)){
    w = rep(1, length(YS))
  }

  # Guessing starting values ---------------------------------------------

  if (is.null(start)){
    start_guess <- step2(YS     = YS,
                         XS     = XS,
                         YO     = YO,
                         XO     = XO,
                         Msigma = Msigma,
                         Mrho   = Mrho,
                         w      = w)

    start <- c(start_guess$selection,
               start_guess$outcome,
               start_guess$dispersion,
               start_guess$correlation)

    gc()
  }


  # fit model ------------------------------------------------------------

  result = fitheckmanGE(start  =  start,
                        YS     =  YS,
                        XS     =  XS,
                        YO     =  YO,
                        XO     =  XO,
                        Msigma =  Msigma,
                        Mrho   =  Mrho,
                        w      =  w)

  # preparing results ----------------------------------------------------

  result = c(list(call = mf),

             result,

             list(model.frames = list(model.frame.selection = mfS,
                                      model.frame.outcome        = mfO,
                                      model.frame.dispersion     = mfD,
                                      model.frame.correlation    = mfC)))

  class(result) <- "heckmanGE"


  # clustered errors -----------------------------------------------------

  if(!is.null(cluster)){

    m <- match(c("cluster", "data", "subset"), names(mf), 0)

    mf_cluster           <- mf[c(1, m)]
    names(mf_cluster)[2] <- "formula"

    mf_cluster$data = quote(data)
    mf_cluster[[1]] <- as.name("model.frame")
    mf_cluster <- eval(mf_cluster)

    vcov_clustered <- vcovCL.heckmanGE(result, cluster = mf_cluster)
    se_clustered   = sqrt(diag(vcov_clustered))

    result$vcov         = vcov_clustered
    result$se           = se_clustered
    result$se.type      = "clustered"
    result$cluster_vars = names(mf_cluster)
  }

  result
}
