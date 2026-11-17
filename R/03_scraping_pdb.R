library(tidyverse)
library(rvest)

mencoes <- read.csv("saida/mencoes_pdb.csv")
codigos <- unique(mencoes$codigo_pdb)

# a pagina do rcsb ja vem montada no html, nao precisa do chromote aqui
site <- "https://www.rcsb.org/structure/"

# so busca o que ainda nao foi buscado (depois isso vira consulta no banco)
arq_estruturas <- "saida/estruturas.csv"
arq_nao_achou <- "saida/codigos_nao_encontrados.csv"

ja_tem <- c()
if (file.exists(arq_estruturas)) ja_tem <- c(ja_tem, read.csv(arq_estruturas)$codigo_pdb)
if (file.exists(arq_nao_achou)) ja_tem <- c(ja_tem, read.csv(arq_nao_achou)$codigo_pdb)
fila <- setdiff(codigos, ja_tem)

message(length(fila), " codigos pra buscar")

# o rcsb escreve "&nbsp" sem ponto e virgula, sobra no texto
pega_campo <- function(page, seletor) {
  x <- page %>% html_element(seletor) %>% html_text2()
  x <- gsub("&nbsp;?", " ", x)
  trimws(str_remove(x, "^[^:]*:"), "both")
}

dados <- map(fila, function(cod) {
  # cod <- fila[1]
  message("Baixando dados de: ", cod)
  Sys.sleep(2)

  # codigo que nao existe da 404 e o read_html para com erro
  page <- tryCatch(read_html(paste0(site, cod)), error = function(e) NULL)
  if (is.null(page)) return(tibble(codigo_pdb = cod, achou = FALSE))

  # codigo reservado e ainda nao liberado cai numa pagina "unreleased" sem titulo (o 25CN fez isso)
  titulo <- page %>% html_element("#structureTitle") %>% html_text2()
  if (is.na(titulo) | trimws(titulo) == "") return(tibble(codigo_pdb = cod, achou = FALSE))

  texto <- gsub("&nbsp;?", " ", html_text2(page))

  tibble(
    codigo_pdb = cod,
    achou = TRUE,
    nome = page %>% html_element("#structureTitle") %>% html_text2(),
    classificacao = pega_campo(page, "#header_classification"),
    organismo = pega_campo(page, "#header_organism"),
    metodo = pega_campo(page, "#exp_header_0_method"),
    # raio x e crio-me usam id diferente pra resolucao
    resolucao = pega_campo(page, "[id^='exp_header_0_'][id$='_resolution']"),
    data_deposito = str_extract(texto, "(?<=Deposited:)\\s*\\d{4}-\\d{2}-\\d{2}"),
    massa_kda = str_extract(pega_campo(page, "#contentStructureWeight"), "[\\d.,]+"),
    n_cadeias = str_extract(texto, "(?<=Unique protein chains: )\\d+"),
    doi_estrutura = pega_campo(page, "#pubmedDOI")
  )
}) %>% list_rbind()

# fila vazia volta tibble sem coluna
if (nrow(dados) == 0) dados <- tibble(codigo_pdb = character(), achou = logical())

nao_achou <- dados %>% filter(!achou) %>% select(codigo_pdb)
if (nrow(nao_achou) > 0) {
  if (file.exists(arq_nao_achou)) nao_achou <- bind_rows(read.csv(arq_nao_achou), nao_achou)
  write.csv(nao_achou, arq_nao_achou, row.names = FALSE)
}

# se a rodada so teve codigo que nao existe, nao tem coluna nenhuma pra arrumar
if (any(dados$achou)) {
  dados <- dados %>%
    filter(achou) %>%
    select(-achou) %>%
    mutate(resolucao = as.numeric(str_extract(resolucao, "[\\d.]+")),
           massa_kda = as.numeric(gsub(",", "", massa_kda)),
           n_cadeias = as.integer(n_cadeias),
           data_deposito = as.Date(trimws(data_deposito)),
           doi_estrutura = str_remove(doi_estrutura, "https://doi.org/"))

  # junta com o que ja tinha
  if (file.exists(arq_estruturas)) dados <- bind_rows(read.csv(arq_estruturas, colClasses = c(data_deposito = "Date")), dados)
  write.csv(dados, arq_estruturas, row.names = FALSE)
}
