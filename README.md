# Datos de GBIF y WorldClim en R

Lección práctica para descargar, depurar y analizar ocurrencias de
[GBIF](https://www.gbif.org) con `rgbif`, y compararlas con variables climáticas de
[WorldClim](https://www.worldclim.org) usando `geodata` y `terra`.

Especies de ejemplo: *Pseudoeurycea leprosa* (salamandra de montaña) e *Incilius valliceps* (sapo de tierras bajas).

## Contenido

```
ejercicio_gbif/
├── ejercicio_gbif.Rproj      # abre este archivo en RStudio
├── index.qmd                 # lección completa (Quarto)
├── _quarto.yml               # configuración de Quarto (salida en docs/)
├── R/
│   └── ejercicio_datos_gbif.R  # el mismo código, para correr línea por línea
├── img/
│   └── especies_imgs_animado.png
├── datos/                    # descargas de GBIF y WorldClim (se crean al correr)
├── figuras/                  # figuras exportadas
└── docs/                     # página web generada (después de renderizar)
```

## Requisitos

- R ≥ 4.1 (se usa el pipe nativo `|>`) y RStudio
- [Quarto](https://quarto.org) (ya viene con RStudio reciente)
- Conexión a internet la primera vez (descarga de GBIF y WorldClim, ~150 MB)

Paquetes:

```r
install.packages(c("rgbif", "tidyverse", "sf", "terra", "geodata", "tidyterra",
                   "rnaturalearth", "rnaturalearthdata", "ggspatial", "paletteer",
                   "ggcorrplot", "ggridges", "patchwork", "plotly", "magick", "here"))
```

## Uso

1. Clona o descarga el repositorio y abre `ejercicio_gbif.Rproj`.
2. Para trabajar en clase: abre `R/ejercicio_datos_gbif.R` y corre línea por línea.
3. Para generar la página web: en la terminal de RStudio ejecuta

   ```bash
   quarto render
   ```

   El resultado queda en `docs/index.html`.

Las descargas se guardan en `datos/` y no se repiten en ejecuciones posteriores.
Los CSV de GBIF son ligeros y pueden subirse al repositorio para que la lección
sea reproducible; los rásters de WorldClim están excluidos en `.gitignore`.

## Publicar en GitHub Pages

1. Renderiza con `quarto render` y sube todo (incluida la carpeta `docs/` y `_freeze/`).
2. En GitHub: **Settings → Pages → Build and deployment → Deploy from a branch**,
   rama `main`, carpeta `/docs`.

`_quarto.yml` usa `freeze: auto`, así que el código solo se vuelve a ejecutar
cuando cambia `index.qmd`.

## Autor

Daniel Auliz-Ortiz · dauliz@cieco.unam.mx
