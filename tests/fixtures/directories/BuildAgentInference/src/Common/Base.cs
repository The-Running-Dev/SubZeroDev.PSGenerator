namespace Fixture.BuildAgent.Common
{
    /// <summary>
    /// Minimal generic build-entry base, standing in for the real NUKE build-class
    /// boilerplate. A future C# source inspector recognizes this shape structurally;
    /// it does not compile or execute it.
    /// </summary>
    public abstract class Base<TParams> where TParams : new()
    {
        /// <summary>Typed parameters hydrated for this build entry.</summary>
        protected TParams Params { get; } = new TParams();
    }
}
