using Nuke.Common;
using Fixture.BuildAgent.Common;

namespace Fixture.BuildAgent.Build
{
    /// <summary>Executes the Docker build type.</summary>
    class DockerBuild : Base<DockerBuildParams>
    {
        Target Docker => _ => _
            .Executes(() => { });
    }

    /// <summary>Executes the Forge build type.</summary>
    class ForgeBuild : Base<ForgeBuildParams>
    {
        Target Forge => _ => _
            .Executes(() => { });
    }
}
