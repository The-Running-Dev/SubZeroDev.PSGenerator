ARG BASE_IMAGE=ghcr.io/the-running-dev/docs-template:latest
FROM ${BASE_IMAGE}

WORKDIR /template

# Replace the template's authored docs and landing pages. The project docs use
# routeBasePath "/" and provide the landing page.
#
# src/theme/NotFound is deliberately kept: since Docusaurus-Template#33 the
# template's 404 only links to routes it was given, so it is safe here. CI's
# docs-build.ps1 overlays without deleting and therefore keeps it too; removing
# it here would make local preview show a different 404 than the published site.
RUN rm -rf ./docs ./src/pages

# Overlay the repository-specific configuration and authored Markdown.
COPY . .

CMD ["sh", "-c", "pnpm run start:docker"]
