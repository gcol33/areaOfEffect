## Resubmission

This is a resubmission. Changes made in response to CRAN feedback:

* Replaced commented-out code in examples with `\donttest{}` (land.Rd)
* Changed file output from user filespace to `tempdir()` (inst/examples/generate_images.R)
* Added `par()` save/restore to all scripts and vignettes that modify graphical parameters

## R CMD check results

0 errors | 0 warnings | 2 notes

* This is a new submission.

The NOTEs are:
1. "New submission" - expected for first CRAN release
2. "unable to verify current time" - transient network issue, not a package problem

## Test environments

* local: Windows 11 (build 26200), R 4.5.2
* win-builder: R-devel, R-release
* mac-builder: R-release
* GitHub Actions: ubuntu-latest (release), macOS-latest (release), windows-latest (release)

## Downstream dependencies

There are currently no downstream dependencies for this package.
