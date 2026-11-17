# Do artigo ao banco de dados: estruturas do PDB citadas na literatura

Trabalho da disciplina FCM 2026 (prof. Thomas Nogueira Vilches).
Ricardo de Paiva Caetano, Pedro Yuji Yashima, José Victor Orlandi.

Pipeline em R que pega um conjunto de artigos, acha os códigos PDB citados no texto,
busca as informações de cada estrutura no PDB e guarda tudo num banco SQL.

## Divisão

| Etapa | Quem |
|---|---|
| 1–2. Seleção dos artigos, download dos PDFs e extração dos códigos | Ricardo |
| 3. Web scraping no PDB | Ricardo |
| 4. Banco SQL (revistas, artigos, menções, estruturas) | Pedro |
| 5. Tratamento e integração das tabelas no tidyverse | Pedro |
| Gráficos, relatório e apresentação | José Victor |

## Artigos

20 artigos de acesso aberto de 2025, 10 de cada revista:

- **IUCrJ**: experimental, quase sempre deposita estrutura nova
- **PLoS Computational Biology**: computacional, normalmente reaproveita estruturas que já existem

Critério: busca na Europe PMC por `JOURNAL + OPEN_ACCESS:y + PUB_YEAR:2025 + ACCESSION_TYPE:pdb`,
só artigo de proteína (tirei os de mineral, cristal orgânico e só RNA/DNA), pelo menos 3 códigos PDB
segundo a Europe PMC, e os 10 mais recentes de cada revista. A lista está em `dados/artigos_selecionados.csv`.

## Como rodar

Rodar da pasta do projeto, na ordem:

```r
source("R/01_baixar_pdfs.R")   # baixa os pdfs pra pasta pdfs/ (fica fora do git)
source("R/02_extrair_pdb.R")   # gera saida/mencoes_pdb.csv
source("R/03_scraping_pdb.R")  # gera saida/estruturas.csv e saida/codigos_nao_encontrados.csv
```

Pacotes: `tidyverse`, `pdftools`, `rvest`.

## Extração dos códigos

- regex `\b[1-9][a-z0-9]{3}\b` sem diferenciar maiúscula, exigindo pelo menos uma letra (senão pega ano)
- só conta se tiver "PDB", "entry", "accession" etc. na mesma linha ou até 6 linhas acima
- na IUCrJ o bloco "PDB references: ... Supporting information" do resumo conta inteiro
- tira ordinal (2nd, 3rd) e unidade (10mJ, 100ms)

Comparando com a mineração de texto da Europe PMC: 170 códigos em comum, 8 que só a gente achou
(alguns são códigos reais, outros são lixo tipo `207A`, que vão cair quando a busca no PDB não achar nada)
e 16 que a gente perdeu (código em figura ou em linha de tabela longe do cabeçalho).

## Scraping no PDB

Para cada código em `saida/mencoes_pdb.csv`, o script entra em `https://www.rcsb.org/structure/<codigo>`
e pega pelo `id` do elemento:

| Coluna | De onde vem |
|---|---|
| `nome` | `#structureTitle` |
| `classificacao` | `#header_classification` |
| `organismo` | `#header_organism` |
| `metodo` | `#exp_header_0_method` |
| `resolucao` (Å) | `#exp_header_0_diffraction_resolution` (raio X) ou `#exp_header_0_em_resolution` (crio-ME); NMR fica NA |
| `data_deposito` | texto "Deposited:" |
| `massa_kda` | `#contentStructureWeight` |
| `n_cadeias` | texto "Unique protein chains:" (cadeias proteicas **únicas**, não o total) |
| `doi_estrutura` | `#pubmedDOI`, DOI da publicação original da estrutura |

Coleta responsável: 2 s entre uma página e outra, e o script só busca o que ainda não está em
`estruturas.csv` nem em `codigos_nao_encontrados.csv`. Código que dá 404 (lixo da extração, tipo `207A`)
ou que existe mas ainda não foi liberado (o `25CN` cai em `/structure/unreleased/`, com a página sem título)
vai para `codigos_nao_encontrados.csv` e não é buscado de novo.

Resultado: 177 códigos únicos → 174 estruturas e 3 não encontrados (`136B`, `207A`, `25CN`).
A resolução só fica NA nas 10 de NMR em solução. 4 estruturas não têm DOI de publicação e 1 não tem organismo.

A página do RCSB já vem pronta no HTML, então aqui dá para usar `read_html()` direto, sem `chromote`.
