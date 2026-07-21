# Characterization Tests: Locking Behavior Before Surgery

A characterization test asserts what the code **does**, not what it should do. It exists to make refactoring safe: if the test goes red during an extraction, you changed behavior — revert or explain.

## Rules

1. **Assert the actual output, bugs included.** If `Normalize(nil)` currently returns `""` instead of an error, the test asserts `""`. Add a comment: `// characterization: current behavior; arguably should error — see issue #NNN`.
2. **Never fix a bug you discover while characterizing.** File it. Fixing it now violates the prime directive (refactor + behavior change in one PR) and — worse — you no longer know if your extraction is faithful.
3. **Write them at the outermost stable boundary** of the component you're about to cut, not against internals you're about to move. Tests against internals die in the refactor; tests against the boundary survive it and verify it.
4. **Coverage target is the seam, not the component.** You need the paths that flow through your planned cut covered, not 100% of the god component. Use the seam inventory to know which paths those are.
5. **Delete or promote them after the campaign.** Post-extraction, either promote a characterization test to a real spec test (rename, fix the asserted bugs deliberately) or delete it in favor of the new unit tests. Don't let "assert whatever it did in 2024" tests accrete.

## Procedure

1. Identify the boundary: the function(s)/handler(s) through which all behavior of the component flows.
2. Fake the I/O dependencies at that boundary (this may require extraction step 1 — widening params to interfaces — first; that's fine, param-widening is behavior-safe without characterization coverage).
3. For each externally distinguishable behavior on your planned cut path, write one test capturing input → exact output, including error values and emitted events (for outbound calls, see "Recording fakes for side effects" below).
4. When you can't predict the output, run the code and paste what it produced into the assertion (golden/snapshot style). That's not lazy — that's the point.
5. Commit the tests in their own PR *before* the first structural change. Green baseline first.

## Recording fakes for side effects

For components whose behavior includes notifications, metrics, or other outbound calls, inject recording fakes and assert the exact call list — method, payload, count — as part of the characterization. An unexpected extra notification is a behavior change even when the return value is identical. Concurrency: assert exact order only where the old code guaranteed order; otherwise assert as a multiset, and note in the test which of the two you're asserting.

## Golden-file variant (for large/streaming outputs)

For components producing large outputs (rendered prompts, protocol message sequences, generated configs), record the real output to `testdata/*.golden` and compare bytes:

```go
func TestTurnEngine_Golden(t *testing.T) {
    got := runScenario(t, "testdata/scenario_greeting.json")
    golden := filepath.Join("testdata", t.Name()+".golden")
    if *update {
        os.WriteFile(golden, got, 0o644)
    }
    want, _ := os.ReadFile(golden)
    if !bytes.Equal(got, want) {
        t.Errorf("output changed:\n%s", diff(want, got))
    }
}
```

With an `-update` flag guarded by review: regenerating goldens must be a deliberate, diff-reviewed act, never a CI auto-fix.

## Shadow mode as runtime characterization

When behavior depends on production traffic you can't enumerate (timing, real user inputs), characterize at runtime: run old and new paths side by side, serve the old path's result, log a structured diff when outputs disagree. Zero diffs over a representative window = the new path is characterized by production itself. Set the comparison window and the old-path kill date when you turn shadow mode on (see SKILL.md, Strangler sequencing).
