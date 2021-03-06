#' Make MOMS-PI MultiAssayExperiment
#'
#' Construct MultiAssayExperiment for MOMS-PI 16S rRNA
#' and cytokines data.
#'
#' @format A MultiAssayExperiment object with a 16S rRNA matrix and Cytokine matrix
#' \subsection{16S}{
#'     A counts matrix for the 16S rRNA-seq results.
#' }
#' \subsection{cytokines}{
#'     A counts matrix for the cytokines results.
#' }
#' \subsection{colData}{
#'    \describe{
#'       \item{file_id}{File identifier}
#'       \item{md5}{md5 hash for the file}
#'       \item{size}{file size}
#'       \item{urls}{URL for the file}
#'       \item{sample_id}{Sample identifier}
#'       \item{file_name}{Filename which the sample was taken from}
#'       \item{subject_id}{Participant identifier}
#'       \item{sample_body_site}{Body site of the sample}
#'       \item{visit_number}{Visit number}
#'       \item{subject_gender}{Participant gender}
#'       \item{subject_race}{Participant race}
#'       \item{study_full_name}{Name of the study}
#'       \item{project_name}{Name of project}
#'    }
#' }
#' @return A multiAssay Experiment object
#' @import MultiAssayExperiment
#' @importFrom dplyr id
#' @export
#' @examples momspiMA <- momspiMultiAssay()
momspiMultiAssay <- function() {
  # load MOMS-PI data
  data("momspi16S_mtx")
  data("momspi16S_samp")
  data("momspiCyto_mtx")
  data("momspiCyto_samp")
  # # Metadata for the 16S and cytokine data
  # make colData
  # add new ID
  momspi16S_samp$id  <- paste0('a', seq(from = 1, to = nrow(momspi16S_samp)))
  momspiCyto_samp$id <- paste0('b', seq(from = 1, to = nrow(momspiCyto_samp)))
  # merge
  common_participants <- dplyr::inner_join(momspi16S_samp, momspiCyto_samp,
                                          by = c("subject_id", "sample_body_site", "visit_number",
                                                 "subject_gender", "subject_race", "study_full_name",
                                                 "project_name",
                                                 "md5", "urls", "size", "file_id"))
  # Get sample data for samples not in merged data.frame
  uncommon <- rbind(momspi16S_samp[! momspi16S_samp$id %in% common_participants$id.x, ],
                    momspiCyto_samp[! momspiCyto_samp$id %in% common_participants$id.y, ])
  # merge common IDs
  common_participants$id   <- paste0(common_participants$id.x, common_participants$id.y)
  # merge file names
  common_participants$file_name <- paste(common_participants$file_name.x, common_participants$file_name.y, sep = '.')
  # merge sample ids
  common_participants$sample_id <- paste(common_participants$sample_id.x, common_participants$sample_id.y, sep = '.')
  # make sample data.frame, using the same columns line "uncommon" object
  samp <- rbind(common_participants[, colnames(uncommon)],
                uncommon)


  rownames(samp) <- samp$file_name
  # Drop "file" column
  samp <- dplyr::select(samp, select = -c(file_name))
  ids <- rownames(samp)
  # set up sampleMap
  # assay column: the name of the assay, and found in the names of ExperimentList list names
  # primary column: identifiers of patients or biological units, and found in the row names of colData
  # colname column: identifiers of assay results, and found
  #     in the column names of ExperimentList elements Helper functions are available for creating a map from a list. See ?listToMap
  # make assay vector
  assay_common <- grepl("\\.", ids)   # Dot-separated IDs
  assay_rna    <- grepl("a", samp$id) # IDs that start with "a"
  # make map for the samples not in common between 16S and cytokines
  map_uncommon <- data.frame(assay   = ifelse(assay_rna, "16S", "cytokines")[!assay_common],
                             primary = rownames(samp)[!assay_common],
                             colname = rownames(samp)[!assay_common],
                             stringsAsFactors = FALSE)
  # make map for the samples in common between 16S and cytokines
  map_common <- data.frame(assay   = c(rep("16S", sum(assay_common)), rep("cytokines", sum(assay_common))),
                           primary = c(rownames(samp)[assay_common], rownames(samp)[assay_common]),
                           colname = c(gsub("\\..*$", "", rownames(samp)[assay_common]), gsub("^.*\\.", "", rownames(samp)[assay_common])),
                           stringsAsFactors = FALSE)
  map <- rbind(map_common, map_uncommon)

  # drop "id" column for sample data
  samp <- dplyr::select(samp, select = -c(id))
  # make multiassay object
  momspiMA <- MultiAssayExperiment(experiments = ExperimentList(`16S` = momspi16S_mtx, cytokines = momspiCyto_mtx),
                                   colData     = samp,
                                   sampleMap   = map)

  return(momspiMA)
}
