# pixel-eater
we eat pixels

## Browser deployment

This repo is set up for GitHub Pages deployment using a Godot web export.

### What is included

- `export_presets.cfg` defines a `Web` export preset that writes to `build/web/index.html`.
- `.github/workflows/deploy-pages.yml` downloads Godot `4.6.1-stable`, installs the matching export templates, exports the project headlessly, and deploys the result to GitHub Pages.
- `project.godot` is configured to use the Compatibility renderer, which is the renderer required for Godot web exports.

### How to publish

1. Push this repository to GitHub.
2. In GitHub, enable Pages for the repository.
3. Set the Pages source to `GitHub Actions`.
4. Push to `main` or run the `Deploy Godot Web Build` workflow manually.

After the workflow completes, the game will be playable from the repository's GitHub Pages URL.
