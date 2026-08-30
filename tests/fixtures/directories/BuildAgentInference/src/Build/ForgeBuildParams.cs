using Nuke.Common;
using Fixture.BuildAgent.Common;

namespace Fixture.BuildAgent.Build
{
    /// <summary>Parameters for the Forge build type.</summary>
    public class ForgeBuildParams : BuildParamsBase
    {
        /// <summary>
        /// Forge output directory. Intentional conflict: the NUKE schema and the
        /// generated <c>parameters.json</c> both default this to "artifacts/forge";
        /// this literal default disagrees with both, for use by focused
        /// precedence/conflict tests once evidence merging exists.
        /// </summary>
        [Parameter]
        public string OutputDirectory { get; set; } = "out";
    }
}
