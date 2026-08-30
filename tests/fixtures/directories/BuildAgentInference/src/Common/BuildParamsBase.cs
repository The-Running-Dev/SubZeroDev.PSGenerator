using System.Collections.Generic;
using Nuke.Common;

namespace Fixture.BuildAgent.Common
{
    /// <summary>
    /// Parameters shared by every build type. An inherited parameter class:
    /// <c>DockerBuildParams</c> and <c>ForgeBuildParams</c> both derive from this.
    /// </summary>
    public abstract class BuildParamsBase
    {
        /// <summary>
        /// Build configuration. Compatible overlap: also declared by the NUKE
        /// schema's "Configuration" property, with the same meaning and type.
        /// </summary>
        [Parameter]
        public string Configuration { get; set; } = "Release";

        /// <summary>Targets to execute.</summary>
        [Parameter]
        public string[] Targets { get; set; }

        /// <summary>Optional labels applied to the produced artifact.</summary>
        [Parameter]
        public List<string> Tags { get; set; }

        /// <summary>Registry authentication token. Never written to logs.</summary>
        [Secret]
        public string RegistryToken { get; set; }
    }
}
