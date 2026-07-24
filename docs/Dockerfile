ARG BASE_IMAGE=ghcr.io/the-running-dev/docs-template:latest
FROM ${BASE_IMAGE}

WORKDIR /template

# Replace the template's authored docs, landing pages, and branded 404 page.
# The project docs use routeBasePath "/" and provide the landing page.
RUN rm -rf ./docs ./src/pages ./src/theme/NotFound

# Overlay the repository-specific configuration and authored Markdown.
COPY . .

CMD ["sh", "-c", "pnpm run start:docker"]
