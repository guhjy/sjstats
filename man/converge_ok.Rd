% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/converge_ok.R
\name{converge_ok}
\alias{converge_ok}
\alias{is_singular}
\title{Convergence test for mixed effects models}
\usage{
converge_ok(x, tolerance = 0.001)

is_singular(x, tolerance = 1e-05)
}
\arguments{
\item{x}{A \code{merMod}-object. For \code{is_singluar()}, may also be a
\code{glmmTMB}-object.}

\item{tolerance}{Indicates up to which value the convergence result is
accepted. The smaller \code{tolerance} is, the stricter the test
will be.}
}
\value{
For \code{converge_ok()}, a logical vector, which is \code{TRUE} if
          convergence is fine and \code{FALSE} if convergence is suspicious.
          Additionally, the convergence value is returned as return value's name.
          \code{is_singluar()} returns \code{TRUE} if the model fit is singular.
}
\description{
\code{converge_ok()} provides an alternative convergence test for
               \code{\link[lme4]{merMod}}-objects; \code{is_singular()} checks
               post-fitting convergence warnings. If the model fit is singular,
               warning about negative eigenvalues of the Hessian can most likely
               be ignored.
}
\details{
\code{converge_ok()} provides an alternative convergence test for
               \code{\link[lme4]{merMod}}-objects, as discussed
               \href{https://github.com/lme4/lme4/issues/120}{here}
               and suggested by Ben Bolker in
               \href{https://github.com/lme4/lme4/issues/120#issuecomment-39920269}{this comment}.
               \cr \cr
               \code{is_singular()} checks if a model fit is singular, and can
               be used in case of post-fitting convergence warnings, such as
               warnings about negative eigenvalues of the Hessian. If the fit
               is singular (i.e. \code{is_singular()} returns \code{TRUE}), these
               warnings can most likely be ignored.
}
\examples{
library(sjmisc)
library(lme4)
data(efc)
# create binary response
efc$hi_qol <- dicho(efc$quol_5)
# prepare group variable
efc$grp = as.factor(efc$e15relat)
# data frame for fitted model
mydf <- data.frame(hi_qol = as.factor(efc$hi_qol),
                   sex = as.factor(efc$c161sex),
                   c12hour = as.numeric(efc$c12hour),
                   neg_c_7 = as.numeric(efc$neg_c_7),
                   grp = efc$grp)
# fit glmer
fit <- glmer(hi_qol ~ sex + c12hour + neg_c_7 + (1|grp),
             data = mydf, family = binomial("logit"))

converge_ok(fit)

}
