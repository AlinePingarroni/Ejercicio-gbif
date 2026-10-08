# =============================================================================
# Título:    Datos de GBIF y WorldClim en R
# Autor:     Daniel Auliz-Ortiz
# Propósito: Descargar, depurar y analizar ocurrencias de GBIF y compararlas
#            con variables climáticas de WorldClim
# Fecha:     21 de octubre de 2025 (revisado en octubre de 2026)
# Contacto:  dauliz@cieco.unam.mx
#
# Cómo usar este script:
#   1. Abre el proyecto "ejercicio_gbif.Rproj" (no solo este archivo).
#   2. Corre el código línea por línea (Ctrl/Cmd + Enter).
#   3. La explicación completa está en "index.qmd" / la página web de la lección.
#   Usa el panel "Outline" de RStudio (Ctrl/Cmd + Shift + O) para navegar
#   entre secciones.
# =============================================================================


# 0. Instalar paquetes (solo la primera vez) -----------------------------------

# paquetes <- c("rgbif", "tidyverse", "sf", "terra", "geodata", "tidyterra",
#               "rnaturalearth", "rnaturalearthdata", "ggspatial", "paletteer",
#               "ggcorrplot", "ggridges", "patchwork", "plotly", "magick", "here")
# faltantes <- paquetes[!paquetes %in% rownames(installed.packages())]
# if (length(faltantes) > 0) install.packages(faltantes)


# 1. Cargar paquetes -----------------------------------------------------------

library(rgbif)         # API de GBIF: nombres, conteos y ocurrencias
library(tidyverse)     # manipulación de tablas y gráficos (ggplot2)
library(sf)            # datos vectoriales (puntos, polígonos)
library(terra)         # datos ráster
library(geodata)       # descarga de WorldClim, elevación, GADM...
library(tidyterra)     # graficar objetos de terra con ggplot2
library(rnaturalearth) # polígonos de países (sustituye a rworldxtra)
library(ggspatial)     # flecha de norte y barra de escala
library(paletteer)     # paletas de colores
library(ggcorrplot)    # matrices de correlación
library(ggridges)      # gráficos de densidad apilados
library(patchwork)     # combinar gráficos
library(plotly)        # gráficos interactivos
library(magick)        # leer imágenes
library(here)          # rutas relativas a la raíz del proyecto

# OJO: tidyr y terra tienen una función extract(). Para evitar confusiones
# usaremos siempre terra::extract().


# 2. Rutas y objetos generales -------------------------------------------------

ruta_datos   <- here("datos")     # descargas
ruta_figuras <- here("figuras")   # figuras
dir.create(ruta_datos,   showWarnings = FALSE)
dir.create(ruta_figuras, showWarnings = FALSE)

# Colores fijos por especie (iguales en todas las figuras)
colores_spp <- c("Pseudoeurycea leprosa" = "#8d62fc",
                 "Incilius valliceps"    = "#fc8d62")

# Zona de estudio: xmin, xmax, ymin, ymax (grados)
zona <- ext(-120, -77, 10, 32)


# 3. Consultas taxonómicas -----------------------------------------------------

# GBIF organiza sus datos con un "esqueleto taxonómico" (backbone). Cada nombre
# tiene una clave numérica (usageKey) y un estatus (ACCEPTED, SYNONYM, DOUBTFUL).

# --- name_backbone(): devuelve UNA sola coincidencia, la mejor ---------------
consulta_A <- name_backbone("Pseudoeurycea")
consulta_A |> select(usageKey, scientificName, rank, status, matchType, confidence)
# matchType: EXACT (exacta), FUZZY (con errores de escritura) o HIGHERRANK
# (solo encontró un nivel superior). FUZZY o HIGHERRANK = revisar.

# Un nombre antiguo del sapo
consulta_B <- name_backbone("Bufo valliceps")
consulta_B |>
  select(any_of(c("usageKey", "scientificName", "status",
                  "acceptedUsageKey", "species", "matchType")))
# Bufo valliceps es SINÓNIMO; el nombre aceptado es Incilius valliceps.
# acceptedUsageKey = clave del nombre aceptado.
# any_of() selecciona solo las columnas que existan (acceptedUsageKey solo
# aparece si el nombre es sinónimo).
# Más información: https://enciclovida.mx/especies/35457-incilius-valliceps

# --- name_suggest(): autocompletar, devuelve VARIAS opciones ----------------
sugerencias_A <- name_suggest(q = "Pseudoeurycea", rank = "species", limit = 100)$data
sugerencias_A
# Información del género: https://enciclovida.mx/especies/25951-pseudoeurycea

sugerencias_B <- name_suggest(q = "Incilius", rank = "species")$data
sugerencias_B

# --- Guardar las claves de nuestras especies --------------------------------
# Buscar por clave (taxonKey) es más seguro que por texto: incluye los
# registros guardados bajo sinónimos.
clave_pse <- name_backbone("Pseudoeurycea leprosa")$usageKey
clave_inc <- name_backbone("Incilius valliceps")$usageKey
c(Pseudoeurycea = clave_pse, Incilius = clave_inc)

# --- name_usage(): ficha completa de un nombre -------------------------------
name_usage(key = clave_inc)$data |>
  select(any_of(c("key", "scientificName", "authorship", "taxonomicStatus",
                  "kingdom", "phylum", "class", "order", "family", "genus")))


# 4. Ocurrencias ---------------------------------------------------------------

# --- occ_count(): ¿cuántos registros hay? ------------------------------------
occ_count(taxonKey = clave_pse)                         # todos
occ_count(taxonKey = clave_pse, hasCoordinate = TRUE)   # con coordenadas
occ_count(taxonKey = clave_inc, hasCoordinate = TRUE)

# --- occ_search() vs occ_download() ------------------------------------------
# occ_search(): exploración y clases; máx. 100 000 registros; sin cuenta; sin DOI
# occ_download(): análisis formales; sin límite; requiere cuenta; genera DOI
#                 (ver sección 9 al final)
#
# Argumentos útiles de occ_search():
#   taxonKey / scientificName  qué especie
#   hasCoordinate = TRUE       solo con coordenadas
#   hasGeospatialIssue = FALSE sin problemas geoespaciales detectados por GBIF
#   country = "MX", year = "1990,2020", basisOfRecord = "PRESERVED_SPECIMEN"
#   limit                      máximo de registros (por defecto 500; NO es
#                              una muestra aleatoria)
#
# El resultado es una LISTA: los registros están en $data.

# Ejemplo directo (no hace falta correrlo, la función de abajo lo hace):
# res_pse <- occ_search(taxonKey = clave_pse, hasCoordinate = TRUE,
#                       hasGeospatialIssue = FALSE, limit = 2000)
# names(res_pse)   # meta, hierarchy, data, media, facets
# Pse_lep <- res_pse$data

# --- Función para descargar y guardar ----------------------------------------
# Las tablas de GBIF tienen más de 100 columnas; guardamos solo las útiles.
# Guardar el CSV en datos/ evita volver a descargar cada vez.
columnas_utiles <- c("key", "species", "scientificName",
                     "decimalLongitude", "decimalLatitude",
                     "coordinateUncertaintyInMeters", "basisOfRecord",
                     "institutionCode", "datasetKey", "countryCode",
                     "stateProvince", "year", "eventDate", "issues")

# Si una columna no vino en la descarga, la agrega vacía
completar_columnas <- function(datos) {
  faltan <- setdiff(columnas_utiles, names(datos))
  datos[faltan] <- NA
  datos[columnas_utiles]   # ordena las columnas
}

descargar_gbif <- function(taxon_key, etiqueta, archivo, limite = 2000) {
  # 1. Si ya existe el archivo, no descargamos de nuevo
  if (!file.exists(archivo)) {
    message("Descargando de GBIF: ", etiqueta)
    res <- occ_search(taxonKey = taxon_key,
                      hasCoordinate = TRUE,
                      hasGeospatialIssue = FALSE,
                      limit = limite)
    res$data |>
      select(any_of(columnas_utiles)) |>
      completar_columnas() |>   # mismas columnas siempre, en el mismo orden
      write_csv(archivo)
  }
  # 2. Siempre leemos desde el CSV, con tipos de columna fijos (así ambas
  #    especies tienen las mismas columnas y se pueden unir sin errores)
  read_csv(archivo,
           col_types = cols(.default = col_character(),
                            decimalLongitude = col_double(),
                            decimalLatitude  = col_double(),
                            coordinateUncertaintyInMeters = col_double(),
                            year = col_integer())) |>
    mutate(especie = etiqueta)
}

Pse_lep <- descargar_gbif(clave_pse, "Pseudoeurycea leprosa",
                          file.path(ruta_datos, "gbif_pseudoeurycea_leprosa.csv"))
dim(Pse_lep)
glimpse(Pse_lep)


# 5. Explorar y depurar ocurrencias --------------------------------------------

# ¿En qué países hay registros?
count(Pse_lep, countryCode, sort = TRUE)

# ¿Qué tipo de registros son?
count(Pse_lep, basisOfRecord, sort = TRUE)
# PRESERVED_SPECIMEN  ejemplar en colección científica (verificable)
# HUMAN_OBSERVATION   observación de una persona (p. ej. iNaturalist)
# MACHINE_OBSERVATION cámaras trampa, sensores, grabaciones
# MATERIAL_SAMPLE, MATERIAL_CITATION, OCCURRENCE: otros orígenes
# Guía: https://docs.gbif.org/course-data-use/es/base-del-registro.html

# ¿Qué instituciones aportan datos?
Pse_lep |>
  count(institutionCode) |>
  ggplot(aes(x = n, y = fct_reorder(institutionCode, n))) +
  geom_col(fill = colores_spp["Pseudoeurycea leprosa"]) +
  labs(x = "Número de registros", y = "Institución (NA = sin dato)") +
  theme_minimal()

# ¿En qué años?
ggplot(Pse_lep, aes(x = year)) +
  geom_histogram(binwidth = 5, fill = colores_spp["Pseudoeurycea leprosa"],
                 color = "white") +
  labs(x = "Año del registro", y = "Número de registros") +
  theme_minimal()

# Problemas detectados por GBIF (códigos separados por comas)
Pse_lep |>
  separate_longer_delim(issues, delim = ",") |>
  count(issues, sort = TRUE)
gbif_issues() |> head(10)   # significado de cada código

# --- Función de depuración ----------------------------------------------------
# Criterios (explícitos y justificables):
#   1. Solo ejemplares de colección y observaciones humanas
#   2. Incertidumbre de la coordenada <= 10 km (NA se conserva)
#   3. Año >= 1950 (WorldClim describe 1970-2000)
#   4. Un solo registro por par de coordenadas (sin duplicados)
# NOTA: ya no eliminamos registros sin institutionCode; un campo vacío no
# significa que el registro sea malo.
limpiar_gbif <- function(datos,
                         tipos = c("HUMAN_OBSERVATION", "PRESERVED_SPECIMEN"),
                         incertidumbre_max = 10000,   # metros
                         anio_min = 1950) {
  datos |>
    filter(basisOfRecord %in% tipos) |>
    filter(is.na(coordinateUncertaintyInMeters) |
             coordinateUncertaintyInMeters <= incertidumbre_max) |>
    filter(!is.na(year), year >= anio_min) |>
    distinct(decimalLongitude, decimalLatitude, .keep_all = TRUE)
}

Pse_lep_limpio <- limpiar_gbif(Pse_lep)
c(original = nrow(Pse_lep), limpio = nrow(Pse_lep_limpio))

# Opcional: limpieza automática con CoordinateCleaner
# library(CoordinateCleaner)
# Pse_lep_cc <- clean_coordinates(Pse_lep_limpio,
#                                 lon = "decimalLongitude", lat = "decimalLatitude",
#                                 species = "especie",
#                                 tests = c("capitals", "centroids", "equal",
#                                           "gbif", "institutions", "zeros"))
# summary(Pse_lep_cc)

# --- De tabla a objeto espacial (sf) ------------------------------------------
# coords: columnas x (longitud) y y (latitud), en ese orden
# crs: GBIF usa WGS 84, código EPSG 4326 (https://epsg.io/4326)
Pse_lep_sp <- st_as_sf(Pse_lep_limpio,
                       coords = c("decimalLongitude", "decimalLatitude"),
                       crs = 4326,
                       remove = FALSE)   # conserva las columnas de coordenadas
Pse_lep_sp
st_crs(Pse_lep_sp)$epsg

# --- Segunda especie: mismos criterios ---------------------------------------
Inc_val <- descargar_gbif(clave_inc, "Incilius valliceps",
                          file.path(ruta_datos, "gbif_incilius_valliceps.csv"))
count(Inc_val, basisOfRecord, sort = TRUE)

Inc_val_limpio <- limpiar_gbif(Inc_val)
c(original = nrow(Inc_val), limpio = nrow(Inc_val_limpio))

Inc_val_sp <- st_as_sf(Inc_val_limpio,
                       coords = c("decimalLongitude", "decimalLatitude"),
                       crs = 4326, remove = FALSE)

# Unimos ambas especies; desde aquí distinguimos por la columna "especie"
ocurrencias_sp <- rbind(Pse_lep_sp, Inc_val_sp)
count(st_drop_geometry(ocurrencias_sp), especie)


# 6. Capas geográficas con geodata ---------------------------------------------

# geodata guarda las capas en "path" y NO las vuelve a descargar si ya existen.
#   worldclim_global(var, res, path)   clima actual global (1970-2000)
#   worldclim_country(country, var, path)  clima de un país a 30 s (~1 km)
#   worldclim_tile(var, lon, lat, path)    mosaico de 30° x 30° a 30 s
#   cmip6_world(model, ssp, time, var, res, path)  clima futuro
#   elevation_global(res, path)        elevación
#   gadm(country, level, path)         límites administrativos
#   world(resolution, path)            límites de países
#
# res (minutos de grado): 10 (~18.5 km), 5 (~9.3 km), 2.5 (~4.6 km), 0.5 (~1 km)

# --- Elevación -----------------------------------------------------------------
alt <- elevation_global(res = 5, path = ruta_datos)
names(alt) <- "elevacion"
alt         # dimensiones, resolución, extensión y CRS

alt_zona <- crop(alt, zona)   # recorta al rectángulo de la zona de estudio
alt_zona

# --- Países -------------------------------------------------------------------
paises <- ne_countries(scale = "medium", returnclass = "sf")

# --- Mapa de ocurrencias --------------------------------------------------------
# Orden de capas: ráster -> países -> puntos (cada geom se dibuja encima)
map_occ <- ggplot() +
  geom_spatraster(data = alt_zona, alpha = 0.6) +
  geom_sf(data = paises, fill = NA, color = "grey25", linewidth = 0.4) +
  geom_sf(data = ocurrencias_sp, aes(color = especie), size = 1.3, alpha = 0.8) +
  coord_sf(xlim = c(-120, -77), ylim = c(10, 32), expand = FALSE) +
  scale_fill_paletteer_c("grDevices::terrain.colors",
                         limits = c(0, 5000), na.value = "transparent") +
  scale_color_manual(values = colores_spp) +
  annotation_north_arrow(location = "bl", which_north = "true",
                         pad_x = unit(0.2, "in"), pad_y = unit(0.4, "in"),
                         style = north_arrow_fancy_orienteering(fill = c("white", "grey60"))) +
  annotation_scale(location = "bl", bar_cols = c("grey60", "white")) +
  labs(fill = "Altitud (msnm)", color = "Especie", x = NULL, y = NULL) +
  theme_minimal()

map_occ


# 7. Clima con WorldClim -------------------------------------------------------

# Variables de worldclim_global():
#   "tavg", "tmin", "tmax"  temperatura mensual (12 capas, °C)
#   "prec"                  precipitación mensual (12 capas, mm)
#   "wind", "vapr"          viento y presión de vapor (12 capas)
#   "bio"                   19 variables bioclimáticas
# En WorldClim 2.1 la temperatura ya está en °C (en la v1.4 venía x10).
# Variables bioclimáticas: https://www.worldclim.org/data/bioclim.html

bio_info <- tibble(
  variable = sprintf("bio_%02d", 1:19),
  descripcion = c(
    "Temperatura media anual (°C)",
    "Rango diurno medio (°C)",
    "Isotermalidad (BIO2/BIO7 × 100)",
    "Estacionalidad de la temperatura (desv. est. × 100)",
    "Temperatura máxima del mes más cálido (°C)",
    "Temperatura mínima del mes más frío (°C)",
    "Rango anual de temperatura (BIO5 − BIO6, °C)",
    "Temperatura media del trimestre más húmedo (°C)",
    "Temperatura media del trimestre más seco (°C)",
    "Temperatura media del trimestre más cálido (°C)",
    "Temperatura media del trimestre más frío (°C)",
    "Precipitación anual (mm)",
    "Precipitación del mes más húmedo (mm)",
    "Precipitación del mes más seco (mm)",
    "Estacionalidad de la precipitación (coef. de variación)",
    "Precipitación del trimestre más húmedo (mm)",
    "Precipitación del trimestre más seco (mm)",
    "Precipitación del trimestre más cálido (mm)",
    "Precipitación del trimestre más frío (mm)"
  )
)
bio_info

env <- worldclim_global(var = "bio", res = 10, path = ruta_datos)
names(env)   # nombres largos: wc2.1_10m_bio_1, ...

# Renombrar con un ciclo for...
v_names <- vector()
for (i in 1:19) {
  v_names[i] <- paste0("bio_", sprintf("%02d", i))  # %02d = 2 dígitos (01, 02...)
}
v_names

# ...o de forma vectorizada, en una sola línea (forma recomendada en R)
names(env) <- sprintf("bio_%02d", 1:19)
env

# --- Recortar (crop) y enmascarar (mask) ---------------------------------------
# crop(): recorta a un rectángulo; mask(): pone NA fuera de un polígono
mexico <- paises |> filter(iso_a3 == "MEX") |> vect()   # sf -> SpatVector

bio_mex <- env[[c("bio_01", "bio_12")]] |>   # [[ ]] selecciona capas
  crop(mexico) |>
  mask(mexico)

plot(bio_mex)   # vista rápida con terra

ggplot() +
  geom_spatraster(data = bio_mex[["bio_01"]]) +
  geom_sf(data = ocurrencias_sp, aes(color = especie), size = 0.8) +
  scale_fill_whitebox_c(palette = "muted", na.value = "transparent") +
  scale_color_manual(values = colores_spp) +
  labs(fill = "BIO1 (°C)", color = "Especie") +
  theme_minimal()

# --- Extraer valores en los puntos --------------------------------------------
# terra::extract(ráster, puntos) devuelve el valor de cada capa en la celda
# donde cae cada punto. ID = FALSE evita la columna de índice.
puntos <- vect(ocurrencias_sp)

valores_bio <- terra::extract(env, puntos, ID = FALSE)
valores_alt <- terra::extract(alt, puntos, ID = FALSE)

df_env <- ocurrencias_sp |>
  st_drop_geometry() |>
  select(especie, decimalLongitude, decimalLatitude) |>
  bind_cols(valores_bio, valores_alt)
head(df_env)

# Puntos en celdas sin datos (p. ej. mar en la costa)
sum(!complete.cases(df_env))
df_env <- drop_na(df_env)
count(df_env, especie)


# 8. Análisis del espacio climático --------------------------------------------

# --- Correlación entre variables ----------------------------------------------
# Importante en modelos de distribución: evitar variables con |r| > 0.7-0.8
mat_cor <- df_env |>
  select(starts_with("bio_")) |>
  cor()

ggcorrplot(mat_cor,
           hc.order = TRUE,   # agrupa variables parecidas (clúster jerárquico)
           type = "lower",    # solo triángulo inferior
           lab = TRUE,        # muestra los valores
           lab_size = 2.5,
           colors = c("blue", "white", "red"))

# Pares más correlacionados
as.data.frame(as.table(mat_cor)) |>
  filter(as.character(Var1) < as.character(Var2), abs(Freq) > 0.8) |>
  arrange(desc(abs(Freq))) |>
  rename(r = Freq)

# --- Distribuciones por especie (ridges) --------------------------------------
# .data[[variable]] usa la columna cuyo nombre está guardado en "variable"
grafico_ridge <- function(variable, titulo) {
  ggplot(df_env, aes(x = .data[[variable]], y = especie, fill = especie)) +
    geom_density_ridges(alpha = 0.8, scale = 1.2, color = "white") +
    scale_fill_manual(values = colores_spp) +
    labs(x = titulo, y = NULL) +
    theme_ridges() +
    theme(legend.position = "none")
}

p_temp   <- grafico_ridge("bio_01",    "Temperatura media anual (°C, BIO1)")
p_precip <- grafico_ridge("bio_12",    "Precipitación anual (mm, BIO12)")
p_alt    <- grafico_ridge("elevacion", "Elevación (msnm)")

p_contraste <- p_temp / p_precip / p_alt   # patchwork: "/" apila verticalmente
p_contraste

ggsave(file.path(ruta_figuras, "contraste_ambiental.png"), p_contraste,
       width = 8, height = 8, units = "in", dpi = 300, bg = "white")

# --- ¿Son diferentes? ---------------------------------------------------------
df_env |>
  group_by(especie) |>
  summarise(n = n(),
            mediana_bio01 = median(bio_01),
            mediana_bio12 = median(bio_12),
            mediana_alt   = median(elevacion))

wilcox.test(bio_01 ~ especie, data = df_env)
# Cautela: los registros de GBIF no son una muestra aleatoria y presentan
# autocorrelación espacial; interpreta el valor de p con cuidado.

# --- Espacio climático en 2D --------------------------------------------------
p_dif_env <- ggplot(df_env, aes(x = bio_12, y = bio_01, color = especie, fill = especie)) +
  geom_point(alpha = 0.5, size = 2) +
  stat_ellipse(geom = "polygon", alpha = 0.2, color = NA, level = 0.95) +
  scale_color_manual(values = colores_spp) +
  scale_fill_manual(values = colores_spp) +
  labs(x = "Precipitación anual (mm)",
       y = "Temperatura media anual (°C)",
       color = "Especie", fill = "Especie",
       title = "Espacio climático de las especies") +
  theme_minimal(base_size = 13)

p_dif_env

# --- Clima a lo largo del año (variables mensuales) ----------------------------
meses <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
           "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")

clima_mensual <- function(var) {
  r <- worldclim_global(var = var, res = 10, path = ruta_datos)
  names(r) <- meses
  terra::extract(r, puntos, ID = FALSE) |>
    mutate(especie = ocurrencias_sp$especie) |>
    pivot_longer(-especie, names_to = "mes", values_to = "valor") |>
    group_by(especie, mes) |>
    summarise(valor = mean(valor, na.rm = TRUE), .groups = "drop") |>
    mutate(variable = var)
}

clima_mes <- bind_rows(clima_mensual("tavg"), clima_mensual("prec")) |>
  mutate(mes = factor(mes, levels = meses),
         variable = recode(variable,
                           tavg = "Temperatura media (°C)",
                           prec = "Precipitación (mm)"))

ggplot(clima_mes, aes(x = mes, y = valor, color = especie, group = especie)) +
  geom_line(linewidth = 1) +
  geom_point() +
  facet_wrap(~variable, ncol = 1, scales = "free_y") +
  scale_color_manual(values = colores_spp) +
  labs(x = NULL, y = NULL, color = "Especie") +
  theme_minimal()

# --- Figura compuesta ---------------------------------------------------------
img <- image_read(here("img", "especies_imgs_animado.png"))
img_plot <- wrap_elements(full = grid::rasterGrob(img, interpolate = TRUE))

diseno <- "
AB
CC
"

final_plot <- (p_dif_env + theme(legend.position = "none")) +
  img_plot +
  map_occ +
  plot_layout(design = diseno, heights = c(1, 2))

final_plot

ggsave(file.path(ruta_figuras, "mapa_compuesto.png"), final_plot,
       width = 10, height = 9, units = "in", dpi = 300, bg = "white")

# --- Espacio climático en 3D (plotly) -----------------------------------------
# z = BIO7, rango anual de temperatura
fig_3d <- plot_ly(
  data   = df_env,
  x      = ~bio_12,
  y      = ~bio_01,
  z      = ~bio_07,
  color  = ~especie,
  colors = unname(colores_spp[sort(unique(df_env$especie))]),
  type   = "scatter3d",
  mode   = "markers",
  marker = list(size = 4, opacity = 0.7)
) |>
  layout(
    title = "Espacio climático 3D de dos especies",
    scene = list(
      xaxis = list(title = "Precipitación anual (mm)"),
      yaxis = list(title = "Temp. media anual (°C)"),
      zaxis = list(title = "Rango anual de temp. (°C)")
    )
  )

fig_3d

htmlwidgets::saveWidget(fig_3d, file.path(ruta_figuras, "espacio_ambiental_3D.html"))


# 9. Más funciones útiles (opcional) -------------------------------------------
# Esta sección está comentada. Quita el # de las líneas que quieras probar.

# --- Descarga formal con DOI: occ_download() ----------------------------------
# Requiere cuenta en gbif.org. Guarda tus credenciales en .Renviron
# (NUNCA en el script):
# usethis::edit_r_environ()
#   GBIF_USER="tu_usuario"
#   GBIF_PWD="tu_contraseña"
#   GBIF_EMAIL="tu_correo"
# (guarda el archivo y reinicia R)

# descarga <- occ_download(
#   pred_in("taxonKey", c(clave_pse, clave_inc)),
#   pred("hasCoordinate", TRUE),
#   pred("hasGeospatialIssue", FALSE),
#   pred_in("basisOfRecord", c("HUMAN_OBSERVATION", "PRESERVED_SPECIMEN")),
#   pred_gte("year", 1950),
#   format = "SIMPLE_CSV"
# )
# occ_download_wait(descarga)
# datos_doi <- occ_download_get(descarga, path = ruta_datos) |>
#   occ_download_import()
# gbif_citation(descarga)   # cita con DOI
#
# pred() igual a; pred_in() uno de varios; pred_gte()/pred_lte() mayor/menor
# o igual; pred_within() dentro de un polígono WKT

# --- Clima a ~1 km para un país -----------------------------------------------
# tavg_mex <- worldclim_country("MEX", var = "tavg", path = ruta_datos)

# --- Clima futuro: cmip6_world() ----------------------------------------------
# ssp: "126", "245", "370", "585"; time: "2021-2040", "2041-2060", "2061-2080"
# bio_2050 <- cmip6_world(model = "MPI-ESM1-2-HR", ssp = "585",
#                         time = "2041-2060", var = "bioc",
#                         res = 10, path = ruta_datos)
# names(bio_2050) <- sprintf("bio_%02d", 1:19)
# futuro <- terra::extract(bio_2050[["bio_01"]], puntos, ID = FALSE)
# df_cambio <- tibble(especie = ocurrencias_sp$especie,
#                     actual  = valores_bio$bio_01,
#                     futuro  = futuro$bio_01) |>
#   mutate(cambio = futuro - actual)
# df_cambio |> group_by(especie) |> summarise(cambio_medio = mean(cambio, na.rm = TRUE))

# --- Límites administrativos: gadm() ------------------------------------------
# estados <- gadm("MEX", level = 1, path = ruta_datos) |> st_as_sf()
# ggplot() +
#   geom_sf(data = estados, fill = "grey95") +
#   geom_sf(data = ocurrencias_sp, aes(color = especie), size = 0.8) +
#   scale_color_manual(values = colores_spp) +
#   theme_minimal()


# 10. Ejercicios ----------------------------------------------------------------
# 1. Cambia incertidumbre_max a 1000 m y anio_min a 1970 en limpiar_gbif().
#    ¿Cuántos registros pierdes? ¿Cambian las conclusiones?
# 2. Elige otra especie de Pseudoeurycea de sugerencias_A y repite el análisis.
# 3. Haz un gráfico de densidad para BIO15 (estacionalidad de la precipitación).
#    ¿Qué especie vive en climas más estacionales?
# 4. Con la matriz de correlación, elige 5-6 variables con |r| < 0.7 entre ellas.
# 5. Usa cmip6_world() para estimar el cambio de temperatura media anual en los
#    sitios de cada especie hacia 2041-2060.
