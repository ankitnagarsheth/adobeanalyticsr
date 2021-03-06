% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/auth.R
\name{aw_token}
\alias{aw_token}
\title{OAuth2 Token for Adobe Analytics}
\usage{
aw_token(
  client_id = Sys.getenv("AW_CLIENT_ID"),
  client_secret = Sys.getenv("AW_CLIENT_SECRET"),
  use_oob = TRUE
)
}
\arguments{
\item{client_id}{defined by global variable or manually defined}

\item{client_secret}{defined by global variable or manually defined}

\item{use_oob}{for the purpose of testing. Default is set to TRUE}
}
\description{
OAuth2 Token for Adobe Analytics
}
