# areaOfEffect 0.1.0

* Initial release
* `aoe()` function for classifying points by spatial support at scale
* Fixed scale = 1 (one full stamp, doubling distance from centroid)
* Multiple supports: process several regions at once (long format output)
* Optional mask for hard boundaries (e.g., coastlines)
* `aoe_summary()` for diagnostic statistics (counts and proportions)
* Returns sf POINT object with `support_id` and `aoe_class` columns
