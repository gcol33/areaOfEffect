#' @keywords internal
"_PACKAGE"

# The bundled datasets and all results are sf objects that are subset and
# combined with `[`, `$<-` and `rbind()`. Importing from sf loads its
# namespace together with areaOfEffect, which registers sf's S3 methods for
# these generics without requiring the user to attach sf.
#' @importFrom sf st_geometry
NULL
