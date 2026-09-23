# Demo assets

Photos for Nora's wishes in screenshot mode (Developer settings, Debug builds only).

Drop any of these files here as `.jpg`, `.jpeg`, `.png` or `.heic`, in any letter case
(`Wool-Coat.HEIC` works too):

| Wish | File |
| --- | --- |
| Wool coat | `wool-coat.jpg` |
| Ceramics class | `ceramics-class.jpg` |
| Noise-cancelling headphones | `noise-cancelling-headphones.jpg` |
| Linen bedding set | `linen-bedding-set.jpg` |

The "Copy demo assets in Debug" build phase in `project.yml` copies the images into the app bundle
under the lowercase name only when the configuration is Debug, so a Release build never carries them
(the "Check Release carries no screenshot mode" build phase checks this). Any other file here, say a
name with spaces, gets a build warning that it is not used. A wish without a file keeps the no-image
placeholder. Each image is downsampled the way the wish editor does it (1024 px, JPEG, under 1 MB)
when screenshot mode is entered. A new or replaced file shows up after the next Debug build and the
next entry into screenshot mode.
