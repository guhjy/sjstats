#' @title Access information from model objects
#' @name pred_vars
#'
#' @description Several functions to retrieve information from model objects,
#'    like variable names, link-inverse function, model frame etc.
#'
#' @param x A fitted model; for \code{var_names()}, \code{x} may also be a
#'    character vector.
#' @param fe.only Logical, if \code{TRUE} (default) and \code{x} is a mixed effects
#'    model, returns the model frame for fixed effects only.
#'
#' @return For \code{pred_vars()} and \code{resp_var()}, the name(s) of the
#'    response or predictor variables from \code{x} as character vector.
#'    \code{resp_val()} returns the values from \code{x}'s response vector.
#'    \code{link_inverse()} returns, if known, the inverse link function from
#'    \code{x}; else \code{NULL} for those models where the inverse link function
#'    can't be identified. \code{model_frame()} is similar to \code{model.frame()},
#'    but should also work for model objects that don't have a S3-generic for
#'    \code{model.frame()}. \code{var_names()} returns the "cleaned" variable
#'    names, i.e. things like \code{s()} for splines or \code{log()} are
#'    removed.
#'
#'
#' @examples
#' data(efc)
#' fit <- lm(neg_c_7 ~ e42dep + c161sex, data = efc)
#'
#' pred_vars(fit)
#' resp_var(fit)
#' resp_val(fit)
#'
#' link_inverse(fit)(2.3)
#'
#' # example from ?stats::glm
#' counts <- c(18, 17, 15, 20, 10, 20, 25, 13, 12)
#' outcome <- gl(3, 1, 9)
#' treatment <- gl(3, 3)
#' m <- glm(counts ~ outcome + treatment, family = poisson())
#'
#' link_inverse(m)(.3)
#' # same as
#' exp(.3)
#'
#' outcome <- as.numeric(outcome)
#' m <- glm(counts ~ log(outcome) + as.factor(treatment), family = poisson())
#' var_names(m)
#'
#' @importFrom stats formula terms
#' @export
pred_vars <- function(x) {
  if (inherits(x, "brmsfit"))
    av <- all.vars(stats::formula(x)$formula[[3L]])
  else
    av <- all.vars(stats::formula(x)[[3L]])

  if (length(av) == 1 && av == ".")
    av <- all.vars(stats::terms(x))

  av
}

#' @rdname pred_vars
#' @export
resp_var <- function(x) {
  if (inherits(x, "brmsfit"))
    deparse(stats::formula(x)$formula[[2L]])
  else
    deparse(stats::formula(x)[[2L]])
}


#' @rdname pred_vars
#' @importFrom nlme getResponse
#' @export
resp_val <- function(x) {
  if (inherits(x, c("lme", "gls")))
    as.vector(nlme::getResponse(x))
  else
    as.vector(model_frame(x)[[var_names(resp_var(x))]])
}


#' @rdname pred_vars
#' @importFrom stats family binomial gaussian
#' @export
link_inverse <- function(x) {

  # handle glmmTMB models
  if (inherits(x, "glmmTMB")) {
    ff <- stats::family(x)

    if ("linkinv" %in% names(ff))
      return(ff$linkinv)
    else
      return(match.fun("exp"))
  }


  # for gam-components from gamm4, add class attributes, so family
  # function works correctly

  if (inherits(x, "gam") && !inherits(x, c("glm", "lm")))
    class(x) <- c(class(x), "glm", "lm")


  # do we have glm? if so, get link family. make exceptions
  # for specific models that don't have family function

  if (inherits(x, c("truncreg", "coxph"))) {
    il <- NULL
  } else if (inherits(x, c("hurdle", "zeroinfl"))) {
    il <- x$linkinv
  } else if (inherits(x, c("lme", "plm", "gls", "lm")) && !inherits(x, "glm")) {
    il <- stats::gaussian(link = "identity")$linkinv
  } else if (inherits(x, "betareg")) {
    il <- x$link$mean$linkinv
  } else if (inherits(x, "vgam")) {
    il <- x@family@linkinv
  } else if (inherits(x, "brmsfit")) {
    fam <- stats::family(x)
    ff <- get(fam$family, asNamespace("stats"))
    il <- ff(fam$link)$linkinv
  } else if (inherits(x, c("lrm", "polr", "clm", "logistf", "multinom", "Zelig-relogit"))) {
    # "lrm"-object from pkg "rms" have no family method
    # so we construct a logistic-regression-family-object
    il <- stats::binomial(link = "logit")$linkinv
  } else {
    # get family info
    il <- stats::family(x)$linkinv
  }

  il
}


#' @rdname pred_vars
#' @importFrom stats model.frame formula getCall
#' @importFrom prediction find_data
#' @importFrom purrr map_lgl map
#' @importFrom dplyr select bind_cols
#' @importFrom tibble as_tibble
#' @importFrom tidyselect one_of
#' @export
model_frame <- function(x, fe.only = TRUE) {
  if (inherits(x, c("merMod", "lmerMod", "glmerMod", "nlmerMod", "merModLmerTest")))
    fitfram <- stats::model.frame(x, fixed.only = fe.only)
  else if (inherits(x, "lme"))
    fitfram <- x$data
  else if (inherits(x, c("vgam", "gee", "gls")))
    fitfram <- prediction::find_data(x)
  else if (inherits(x, "Zelig-relogit"))
    fitfram <- get_zelig_relogit_frame(x)
  else
    fitfram <- stats::model.frame(x)


  # clean 1-dimensional matrices

  fitfram <- purrr::modify_if(fitfram, is.matrix, function(x) {
    if (dim(x)[2] == 1)
      as.vector(x)
    else
      x
  })


  # check if we have any matrix columns, e.g. from splines

  mc <- purrr::map_lgl(fitfram, is.matrix)


  # don't change response value, if it's a matrix
  # bound with cbind()

  if (mc[1] && resp_var(x) == colnames(fitfram)[1]) mc[1] <- FALSE


  # if we have any matrix columns, we remove them from original
  # model frame and convert them to regular data frames, give
  # proper column names and bind them back to the original model frame

  if (any(mc)) {
    fitfram_matrix <- dplyr::select(fitfram, -which(mc))
    spline.term <- var_names(names(which(mc)))

    # try to get model data from environment
    md <- eval(stats::getCall(x)$data, environment(stats::formula(x)))

    # if data not found in environment, reduce matrix variables into regular vectors
    if (is.null(md))
      fitfram <- dplyr::bind_cols(purrr::map(fitfram, ~ tibble::as_tibble(.x)))
    else
      fitfram <- dplyr::bind_cols(fitfram_matrix, dplyr::select(md, tidyselect::one_of(spline.term)))
  }

  # clean variable names
  colnames(fitfram) <- var_names(colnames(fitfram))

  fitfram
}

#' @importFrom dplyr select
get_zelig_relogit_frame <- function(x) {
  vars <- c(resp_var(x), pred_vars(x))
  dplyr::select(x$data, !! vars)
}

#' @rdname pred_vars
#' @importFrom purrr map_chr
#' @export
var_names <- function(x) {
  if (is.character(x))
    get_vn_helper(x)
  else
    get_vn_helper(colnames(model_frame(x)))
}


#' @importFrom sjmisc is_empty
#' @importFrom purrr map_chr
get_vn_helper <- function(x) {

  # return if x is empty
  if (sjmisc::is_empty(x)) return("")

  # for gam-smoothers/loess, remove s()- and lo()-function in column name
  # for survival, remove strata(), and so on...
  pattern <- c("as.factor", "log", "lag", "diff", "lo", "bs", "ns", "mi", "pspline", "poly", "strata", "offset", "s")

  # do we have a "log()" pattern here? if yes, get capture region
  # which matches the "cleaned" variable name
  purrr::map_chr(1:length(x), function(i) {
    for (j in 1:length(pattern)) {
      p <- paste0("^", pattern[j], "\\(([^,)]*).*")
      x[i] <- unique(sub(p, "\\1", x[i]))
    }
    x[i]
  })
}
