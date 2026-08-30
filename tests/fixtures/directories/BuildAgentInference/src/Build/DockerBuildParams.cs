using Nuke.Common;
using Fixture.BuildAgent.Common;

namespace Fixture.BuildAgent.Build
{
    /// <summary>Parameters for the Docker build type.</summary>
    public class DockerBuildParams : BuildParamsBase
    {
        /// <summary>Tag applied to the built image.</summary>
        [Parameter]
        public string ImageTag { get; set; } = "latest";

        /// <summary>Maximum number of build-time arguments accepted.</summary>
        [Parameter]
        public int? MaxBuildArgs { get; set; }
    }
}
