library(tidyverse)

artigos <- read.csv("dados/artigos_selecionados.csv")

# os pdfs vem do bucket aberto do PMC na AWS, o site normal barra download automatico
bucket <- "https://pmc-oa-opendata.s3.amazonaws.com"

dir.create("pdfs", showWarnings = FALSE)

for (i in 1:nrow(artigos)) {
  # i <- 1 # indice
  pmc <- artigos$pmcid[i]
  arquivo <- sprintf("pdfs/%02d_%s.pdf", artigos$id[i], pmc)

  # se ja baixou nao baixa de novo
  if (file.exists(arquivo)) next

  lista <- paste(readLines(paste0(bucket, "/?list-type=2&prefix=", pmc, "."), warn = FALSE), collapse = "")

  # tem pdf de material suplementar junto, so quero o PMCxxx.N.pdf
  chaves <- str_extract_all(lista, paste0(pmc, "\\.\\d+/", pmc, "\\.\\d+\\.pdf"))[[1]]
  if (length(chaves) == 0) {
    message("Sem pdf: ", pmc)
    next
  }

  message("Baixando: ", pmc)
  download.file(paste0(bucket, "/", tail(sort(chaves), 1)), arquivo, mode = "wb", quiet = TRUE)
  Sys.sleep(2)
}
