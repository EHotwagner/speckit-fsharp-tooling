// prelude.fsx — load the packed library from your local NuGet cache.
//
// Principle I: every non-trivial change starts in FSI against the public
// surface. This prelude gives you that surface in one #load.
//
// Usage from FSI (dotnet fsi or VS Code Ionide):
//   dotnet fsi
//   > #load "scripts/prelude.fsx" ;;
//   > open SpeckitFSharpLib ;;
//   > Library.add 2 3 ;;

// Resolve the latest locally-packed version from ~/.local/share/nuget-local/.
// After `dotnet pack`, the patch version bumps; the #r below pulls the
// highest SemVer.
#i "nuget: file:///home/developer/.local/share/nuget-local/"
#r "nuget: SpeckitFSharpLib"

open SpeckitFSharpLib

printfn "prelude: SpeckitFSharpLib loaded. Try: Library.add 2 3"
