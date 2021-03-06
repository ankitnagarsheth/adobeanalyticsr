% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/anomaly_report.R
\name{aw_anomaly_report}
\alias{aw_anomaly_report}
\title{Anomaly Report}
\usage{
aw_anomaly_report(
  company_id = Sys.getenv("AW_COMPANY_ID"),
  rsid = Sys.getenv("AW_REPORTSUITE_ID"),
  date_range = c(Sys.Date() - 31, Sys.Date() - 1),
  metrics,
  granularity = "day",
  segmentId = NA,
  quickView = FALSE,
  anomalyDetection = TRUE,
  countRepeatInstances = TRUE,
  debug = FALSE
)
}
\arguments{
\item{company_id}{Company Id.  Taken from the global environment by default if not provided.}

\item{rsid}{Adobe report number}

\item{date_range}{A two length vector of start and end Date objects (default set to show last 30 days)}

\item{metrics}{Metric to request the anomaly detection. If multiple metrics, each metric and date will have it's own row.}

\item{granularity}{Use either hour, day (default), week, or month}

\item{segmentId}{Use segments to globally filter the results. Use 1 or many.}

\item{quickView}{Return a list of 3 lists per metric. 1. All Data 2. Data filtered to include only anomalous rows 3. Interactive ggplot line graph}

\item{anomalyDetection}{logical statement for including anomaly. Default is TRUE}

\item{countRepeatInstances}{Should the data include repeat instances}

\item{debug}{default is FALSE but set to TRUE to see the json request being sent to the Adobe API}
}
\description{
Get an anomaly report for one or more metrics
}
