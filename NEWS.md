# areaOfEffect 0.1.0

* Initial release
* `aoe()` function for classifying points by spatial support at scale
* Fixed scale = 1 (one full stamp, doubling distance from reference)
* Optional mask for hard boundaries (e.g., coastlines)
* Returns sf POINT object with `aoe_class` column ("core" or "halo")
