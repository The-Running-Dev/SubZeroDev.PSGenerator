import {type ReactNode} from 'react';
import Heading from '@theme/Heading';
import Link from '@docusaurus/Link';

/**
 * Overrides the base image's branded 404 content.
 *
 * The template's Custom404 component links to /docs and /demos. Neither route
 * exists in this project: the documentation is served from the site root
 * (docs routeBasePath '/') and the pages plugin is disabled, so those links
 * fail the build's broken-link check. This replacement points at the one route
 * that is always present.
 */
export default function NotFoundContent({
  className,
}: {
  className?: string;
}): ReactNode {
  return (
    <main className={className}>
      <div className="row">
        <div className="col col--6 col--offset-3">
          <Heading as="h1" className="hero__title">
            Page Not Found
          </Heading>
          <p>We could not find what you were looking for.</p>
          <p>
            <Link to="/">Return to the documentation home page.</Link>
          </p>
        </div>
      </div>
    </main>
  );
}
