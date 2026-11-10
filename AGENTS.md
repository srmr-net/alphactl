# Repository Guidelines

## Project Structure & Module Organization

This workspace is an initial scaffold: no application source, tests, assets, or build manifests are currently present. The project name is `alphactl`, but its language and architecture have not yet been established.

When adding the first implementation, organize code by responsibility and document the resulting layout here. Keep tests alongside their modules or in a clearly named `tests/` directory, and store static assets separately if needed. Avoid creating empty directories for components the project does not use.

## Build, Test, and Development Commands

No build, test, lint, or local execution commands are currently configured. Do not assume commands such as `npm test` or `make build` work.

When introducing tooling, provide reproducible setup instructions and record the exact commands in this guide or a root `README.md`. Include dependency installation, local execution, formatting, and test commands as applicable.

## Coding Style & Naming Conventions

Follow the standard conventions of the language selected for the implementation. Use consistent indentation, descriptive names, and small modules with clear responsibilities. Add an appropriate formatter and linter with version-controlled configuration when the toolchain is established. Avoid unrelated formatting changes in functional patches.

## Testing Guidelines

No testing framework or coverage threshold is configured. Introduce tests with the first executable behavior, covering expected results, boundary cases, and failures. Use descriptive test names that identify the behavior under test, and document how contributors can run the suite.

## Commit & Pull Request Guidelines

Git history is unavailable in this workspace, so no existing commit convention can be verified. Use concise, imperative commit subjects, such as `Add configuration parser`, and keep commits focused.

Pull requests should explain the change, its purpose, and how it was validated. Link relevant issues and include screenshots for visible interface changes. Clearly identify setup changes and any checks that could not be run.

## Security & Configuration

Never commit credentials, tokens, or machine-specific secrets. Provide sanitized configuration examples and document required environment variables when configuration is introduced.
