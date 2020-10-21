#' Get a free form report
#'
#' Organizes the arguments into a json string and then structures the data after the internal function makes
#' the api call. Up to 7 dimensions at this time.
#'
#' @param rsid Adobe report suite id number. Taken from the global environment by default if not provided.
#' @param date_range A two length vector of start and end Date objects
#' @param metrics Metric to send
#' @param dimensions Dimension to send
#' @param top How many rows. Defualt is set to 50
#' @param metricSort Presorts the table by metrics. Values are either 'asc' or 'desc'.
#' @param filterType Default is 'breakdown'. This will only change if a segment is used.
#' @param return_nones "return-nones" is the default,
#'
#' @return Data Frame
#'
#' @import assertthat
#' @import httr
#' @import tidyverse
#' @import jsonlite
#' @import httr
#' @import dplyr
#' @import curl
#' @import tidyverse
#' @import stringr
#' @import purrrlyr
#'
#' @export
aa_freeform_report <- function(company_id = Sys.getenv("AA_COMPANY_ID"),
                               rsid = Sys.getenv("AA_REPORTSUITE_ID"),
                               date_range = c("2020-08-01", "2020-09-25"),
                               dimensions = c('page', 'lasttouchchannel', 'mobiledevicetype'),
                               metrics = c("visits", "visitors"),
                               top = c(5),
                               filterType = 'breakdown',
                               metricSort =  'desc',
                               return_nones = "return-nones")
  {
  # 1 Call ------------------------------------------------------------------
  for(i in seq(dimensions)) {
    if(i == 1) {
      finalnames <- c(dimensions, metrics)

      itemId <- list(dimensions)

      finalnames_function <- function(level) {
        c(paste0('itemId_',dimensions[level]), dimensions[level])
      }

      prefinalnames <- map(seq(dimensions), finalnames_function) %>%
        append(list(metrics))


      #based on given names, create the list to be used for filtering and defining
      itemidnamesfunction <- function(items) {
        paste0('itemId_', dimensions[[items]])
      }
      itemidnames <-map(seq(dimensions), itemidnamesfunction)

      ##set the timeframe for the query
      timeframe <- make_timeframe(date_range[[1]], date_range[[2]])

      ##setup the right number of limits for each dimension
      if(length(top) != length(dimensions) & length(top) != 1) {
        stop('TOP length: The "top" number of values must be equal the length of the "dimensions" list or 1 unless the first dimension is a "daterange" metric in which case the number of "top" items only has to match the length of the non "daterange" items.')
      } else if(grepl('daterangeday', dimensions[1])) {
        top <- rep(top, length(dimensions)-1)
        top <- c(as.numeric(as.Date(date_range[2]) - as.Date(date_range[[1]])), top)
      } else if(length(top) == 1) {
        top <- rep(top, length(dimensions))
      }

      ##function to create the top level 'metricsContainer'
      metriccontainer_1 <- function(metric, colId, metricSort = 'desc') {
        if(colId == 0) {
          structure(list(
            columnId = colId,
            id = sprintf('metrics/%s',metric),
            sort = metricSort
          ))
        } else {
          structure(list(
            columnId = colId,
            id = sprintf('metrics/%s',metric)))
        }}

      ### function to create the  breakdown 'metricsContainer'
      metriccontainer_2 <- function(metric, colId, metricSort = 'desc' , filterId) {
        if(colId == 0) {
          structure(list(
            columnId = colId,
            id = sprintf('metrics/%s',metric),
            sort = metricSort,
            filters = list(
              filterId
            )))
        } else {
          structure(list(
            columnId = colId,
            id = sprintf('metrics/%s',metric),
            filters = list(
              filterId
            )))
        }}

      metriccontainer_n <- function(metric, colId, metricSort = 'desc' , filterId) {
        if(colId == 0) {
          structure(list(
            columnId = colId,
            id = sprintf('metrics/%s',metric),
            sort = metricSort,
            filters =
              filterId
          ))
        } else {
          structure(list(
            columnId = colId,
            id = sprintf('metrics/%s',metric),
            filters =
              filterId
          ))
        }}

      #setup the tibble for building the queries
      metIds <- tibble(metrics,colid = seq(length(metrics))-1)

      df <- tibble(dimension = c(dimensions), metric = list(metIds), filterType, top)
      df <- df %>% mutate(breakdownorder = rownames(df))
      bdnumber <- as.numeric(max(df$breakdownorder))
      metnumber <- as.numeric(length(metrics))

      #metrics list items
      #if = 1st dimension
      metricContainerFunction <- function(i){
        mc <- list()
        if(i == 1) {
          mc <- list()
          mc <- map2(df$metric[[i]][[1]], df$metric[[i]][[2]], metriccontainer_1)
          return(mc)
        } else if(i == 2) {
          m2list <- list(metric = df$metric[[i]][[1]], colId = df$metric[[i]][[2]],
                         metricSort = metricSort, filterId = seq(nrow(df$metric[[i]][1])*(i-1))-1)
          mc <- append(mc, values = pmap(m2list, metriccontainer_2))
          return(mc)
        } else  {
          #if = 3rd dimension or more
          L <- list(seq(nrow(df$metric[[i]][1])*(i-1))-1)
          filteridslist <- split(L[[1]], rep(1:nrow(df$metric[[i]][1]), length = length(L[[1]])))

          m3list <- list(metric = df$metric[[i]][[1]],
                         colId = df$metric[[i]][[2]],metricSort = metricSort,
                         filterId = filteridslist)
          mc <-  append(mc, values = pmap(m3list, metriccontainer_n))
          return(mc)
        }
      }

      mlist <- map(seq(bdnumber), metricContainerFunction)


      #generating the body of the first api request
      req_body <- structure(list(rsid = rsid,
                                 globalFilters = list(list(
                                   type = "dateRange",
                                   dateRange = timeframe)),
                                 metricContainer = list(
                                   metrics = mlist[[i]]
                                 ),
                                 dimension = sprintf("variables/%s", df$dimension[[i]]),
                                 settings = list(
                                   countRepeatInstances = TRUE,
                                   limit = top[i],
                                   page = 0,
                                   nonesBehavior = return_nones
                                 ),
                                 statistics = list(
                                   functions = c("col-max", "col-min")
                                 )))

      res <- aa_call_data("reports/ranked", body = req_body, company_id = company_id)

      resrows<- fromJSON(res)


      #conditional statement to determine if the function should terminate and reurn the df or continue on.
      if(length(dimensions) == 1) {
        itemidname <- paste0('itemId_', dimensions[[i]])
        dat <- resrows$rows %>%
          rename(!!itemidname := itemId,
                 !!finalnames[[i]] := value) %>%
          mutate(metrics = list(prefinalnames[[i+1]])) %>%
          unnest(c(metrics, data)) %>%
          spread(metrics, data) %>%
          select(finalnames)
        return(dat)
      } else if(length(dimensions) != i) {
        ## second and not last data pull
        itemidname <- paste0('itemId_', dimensions[[i]])
        dat <- resrows$rows %>%
          select(itemId, value) %>%
          rename(!!itemidname := itemId,
                 !!finalnames[[i]] := value)
      }
  }
# 2 Call -----------------------------------------------------------------
    if(i == 2) {

      #function to pre-create the MetricFilters list needed to iterate through the api alls
      load_dims <- function(dimItems) {
        mflist <- list(dimension = rep(dimensions[1:dimItems], each = metnumber))
        mflist <- append(mflist, values = list('type' = 'breakdown'))
        mflist <- append(mflist, values = list('id' = seq(length(mflist[[1]]))-1))
      }
      #run the function
      mfdims <- map(seq_along(dimensions)-1, load_dims)


      # a function that formats the list of metricFilters to run below the metricsContainer
      metricFiltersFunction <- function(i) {
        mfdimslist <-structure(list(id = mfdims[[i]]$id, type = 'breakdown', dimension = mfdims[[i]]$dimension, itemId = ''))
      }
      #map the function to list out the metricFiltres section of the api call
      lists_built <- map( seq_along(dimensions), metricFiltersFunction)

      ### function to create the breakdown 'metricsFilters'
      metricfilter_n <- function(filterId , type, dimension, itemId = '') {
        list(
          id = filterId,
          type = type,
          dimension = sprintf('variables/%s', dimension),
          itemId = itemId
        )
      }
      #run the list function to genereate the formated json string like list
      mflist <- list(lists_built[[i]]$id, lists_built[[i]]$type, lists_built[[i]]$dimension)


      mf_item <- pmap(mflist, metricfilter_n)

      mf_itemlist <- function(itemid) {
        map(mf_item, update_list, itemId = itemid)
      }

      api2 <- map(dat[[1]], mf_itemlist)

      req_bodies <- function(i, mf = api2) {
        structure(list(rsid = rsid,
                       globalFilters = list(list(
                         type = "dateRange",
                         dateRange = timeframe)),
                       metricContainer = list(
                         metrics = mlist[[i]]
                         ,
                         metricFilters =
                           mf
                       ),
                       dimension = sprintf("variables/%s",df$dimension[[i]]),
                       settings = list(
                         countRepeatInstances = TRUE,
                         limit = top[i],
                         page = 0,
                         nonesBehavior = return_nones
                       ),
                       statistics = list(
                         functions = c("col-max", "col-min")
                       )))
      }

      calls <- map2(i, api2, req_bodies)

      call_data_n <- function(calls) {
        aa_call_data("reports/ranked", body = calls, company_id = company_id)
      }


      res <- map(calls, call_data_n)

      getdata <- function(it) {
        fromJSON(res[[it]])
      }

      res <- map(seq(length(res)),  getdata)

      t = 0

      el <- function(els) {
        if_else(res[[els]]$numberOfElements != 0, t+1, 0)
      }

      elnum <- sum(unlist(map(seq(length(res)), el)))

      rowsdata <- function(it) {
        res[[it]]$rows %>% mutate(!!prefinalnames[[1]][[1]] := dat[[1]][[it]],
                                  !!prefinalnames[[1]][[2]] := dat[[2]][[it]])
      }

      resrows <- map_df(seq(elnum), rowsdata)

      #conditional statement to determine if the function should terminate and reurn the df or continue on.
      if(length(dimensions) != i) {
        ## second and not last data pull
        itemidname <- paste0('itemId_', dimensions[[i]])
        dat <- resrows %>%
          rename(!!itemidname := itemId,
                 !!finalnames[[i]] := value)
        dat <- dat %>% select(-data)

      } else {
        itemidname <- paste0('itemId_', dimensions[[i]])
        dat <- resrows %>%
          rename(!!itemidname := itemId,
                 !!finalnames[[i]] := value) %>%
          mutate(metrics = list(prefinalnames[[i+1]])) %>%
          unnest(c(metrics, data)) %>%
          spread(metrics, data) %>%
          select(finalnames)
        return(dat)
      }
    }

# N Calls -----------------------------------------------------------------
  if(i >= 3 && i <= length(dimensions)) {

      #function to pre-create the MetricFilters list needed to iterate through the api calls
      load_dims <- function(dimItems) {
        mflist <- list(dimension = rep(dimensions[1:dimItems], each = metnumber))
        mflist <- append(mflist, values = list('type' = 'breakdown'))
        mflist <- append(mflist, values = list('id' = seq(length(mflist[[1]]))-1))
      }
      #run the function
      mfdims <- map(seq_along(dimensions)-1, load_dims)


      # a function that formats the list of metricFilters too run below the metricsContainer
      metricFiltersFunction <- function(i) {
        mfdimslist <-structure(list(id = mfdims[[i]]$id, type = 'breakdown', dimension = mfdims[[i]]$dimension))
      }
      #map the function to list out the metricFiltres section of the api call
      lists_built <- map( seq_along(dimensions), metricFiltersFunction)

      ### function to create the breakdown 'metricsFilters'
      metricfilter_n <- function(filterId , type, dimension) {
        list(
          id = filterId,
          type = type,
          dimension = sprintf('variables/%s', dimension)
        )
      }
      #run the list function to genereate the formated json string like list
      mflist <- list(lists_built[[i]]$id, lists_built[[i]]$type, lists_built[[i]]$dimension)

      #pulls together all the main items minus the itemIds for the query
      mf_item <- pmap(mflist, metricfilter_n)

      #build the item ids needed for the next query
      mf_itemlist <- function(itemid) {
        ids <- map(map_depth(itemid, 1, unlist), rep,  each = length(metrics))
      }

      selectlist <- list()
      for(series in seq(i-1)){
        selectlist <-  append(selectlist, itemidnames[[series]])
      }
      itemidlist_n <- select(dat, unlist(selectlist))

      listum <- list()

      for(n_item in seq(nrow(itemidlist_n))) {
        listum <- append(listum, list(paste(itemidlist_n[n_item, ])))
      }
      itemidlist_n <- listum

      ##Create the itemids list in the correct number of times.
      itemidser <- map(itemidlist_n, mf_itemlist)

      ##join the 2 different itemids in their correct order. (ncapable)
      listing <- function(p = seq(itemidser)) {
        unlist(itemidser[[p]], use.names = F)
      }

      ##creating the list of lists for the appropriate number of metricFilter items (ncapable)
      itemidser <- map(seq(itemidser),  listing)

      #duplicate the list to match the list length of the next api call (ncapable)
      mf_list <- rep(list(mf_item), length(itemidser))

      #create the list that will hold the list of api calls (ncapable)
      apicalls <- rep(list(rep(list(), length(mf_list[[1]]))), length(mf_list))

      for(l in seq(mf_list)) {
        for(t in seq(mf_list[[1]])) {
          apicalls[[l]][[t]] <- append(mf_list[[l]][[t]],  list('itemId'=itemidser[[l]][t]))
        }
      }

      #(ncapable)
      req_bodies <- function(i, mf = apicalls) {
        structure(list(rsid = rsid,
                       globalFilters = list(list(
                         type = "dateRange",
                         dateRange = timeframe)),
                       metricContainer = list(
                         metrics = mlist[[i]]
                         ,
                         metricFilters =
                           mf
                       ),
                       dimension = sprintf("variables/%s",df$dimension[[i]]),
                       settings = list(
                         countRepeatInstances = TRUE,
                         limit = top[i],
                         page = 0,
                         nonesBehavior = return_nones
                       ),
                       statistics = list(
                         functions = c("col-max", "col-min")
                       ) ) )
      }

      #(ncapable)
      calls <- map2(i, apicalls, req_bodies)

      #(ncapable)
      call_data_n <- function(calls) {
        aa_call_data("reports/ranked", body = calls, company_id = company_id)
      }

      #(ncapable)
      res <- map(calls, call_data_n)

      #(ncapable)
      getdata <- function(it) {
        fromJSON(res[[it]])
      }

      #(ncapable)
      resn <- map(seq(length(res)),  getdata)

      #(ncapable)
      rowsdata <- function(it) {
        if(i == 3) {
          tf <- resn[[it]]$rows %>% mutate(!!prefinalnames[[1]][[1]] := dat[[3]][it],
                                           !!prefinalnames[[1]][[2]] := dat[[4]][it],
                                           !!prefinalnames[[2]][[1]] := dat[[1]][it],
                                           !!prefinalnames[[2]][[2]] := dat[[2]][it])
          return(tf)
        }
        if(i == 4) {
          tf <- resn[[it]]$rows %>% mutate(!!prefinalnames[[1]][[1]] := dat[[5]][it],
                                           !!prefinalnames[[1]][[2]] := dat[[6]][it],
                                           !!prefinalnames[[2]][[1]] := dat[[3]][it],
                                           !!prefinalnames[[2]][[2]] := dat[[4]][it],
                                           !!prefinalnames[[3]][[1]] := dat[[1]][it],
                                           !!prefinalnames[[3]][[2]] := dat[[2]][it])
          return(tf)
        }
        if(i == 5) {
          tf <- resn[[it]]$rows %>% mutate(!!prefinalnames[[1]][[1]] := dat[[7]][it],
                                           !!prefinalnames[[1]][[2]] := dat[[8]][it],
                                           !!prefinalnames[[2]][[1]] := dat[[5]][it],
                                           !!prefinalnames[[2]][[2]] := dat[[6]][it],
                                           !!prefinalnames[[3]][[1]] := dat[[3]][it],
                                           !!prefinalnames[[3]][[2]] := dat[[4]][it],
                                           !!prefinalnames[[4]][[1]] := dat[[1]][it],
                                           !!prefinalnames[[4]][[2]] := dat[[2]][it])
          return(tf)
        }
        if(i == 6) {
          tf <-  resn[[it]]$rows %>% mutate(!!prefinalnames[[1]][[1]] := dat[[9]][it],
                                            !!prefinalnames[[1]][[2]] := dat[[10]][it],
                                            !!prefinalnames[[2]][[1]] := dat[[7]][it],
                                            !!prefinalnames[[2]][[2]] := dat[[8]][it],
                                            !!prefinalnames[[3]][[1]] := dat[[6]][it],
                                            !!prefinalnames[[3]][[2]] := dat[[5]][it],
                                            !!prefinalnames[[4]][[1]] := dat[[3]][it],
                                            !!prefinalnames[[4]][[2]] := dat[[4]][it],
                                            !!prefinalnames[[5]][[1]] := dat[[1]][it],
                                            !!prefinalnames[[5]][[2]] := dat[[2]][it])
          return(tf)
        }
        if(i == 7) {
          tf <- resn[[it]]$rows %>% mutate(!!prefinalnames[[1]][[1]] := dat[[11]][it],
                                           !!prefinalnames[[1]][[2]] := dat[[12]][it],
                                           !!prefinalnames[[2]][[1]] := dat[[9]][it],
                                           !!prefinalnames[[2]][[2]] := dat[[10]][it],
                                           !!prefinalnames[[3]][[1]] := dat[[7]][it],
                                           !!prefinalnames[[3]][[2]] := dat[[8]][it],
                                           !!prefinalnames[[4]][[1]] := dat[[6]][it],
                                           !!prefinalnames[[4]][[1]] := dat[[5]][it],
                                           !!prefinalnames[[5]][[1]] := dat[[3]][it],
                                           !!prefinalnames[[5]][[1]] := dat[[4]][it],
                                           !!prefinalnames[[6]][[1]] := dat[[1]][it],
                                           !!prefinalnames[[6]][[1]] := dat[[2]][it])
          return(tf)
        }
      }


      resrows <- map_df(seq(length(resn)), rowsdata)


      if(length(dimensions) != i) {
        ## second and not last data pull
        itemidname <- paste0('itemId_', finalnames[[i]])
        dat <- resrows %>%
          rename(!!itemidname := itemId,
                 !!finalnames[[i]] := value)
        dat <- dat %>% select(-data)

      } else {
        itemidname <- paste0('itemId_', dimensions[[i]])
        dat <- resrows %>%
          rename(!!itemidname := itemId,
                 !!finalnames[[i]] := value) %>%
          mutate(metrics = list(prefinalnames[[i+1]])) %>%
          unnest(c(metrics, data)) %>%
          spread(metrics, data) %>%
          select(finalnames)
        dat
      }

    }
  }
}