# ERC-8323: Source-Token Agent Binding for ERC-8004

- **Spec**: [ERC-8323 (ethereum/ERCs PR #1851)](https://github.com/ethereum/ERCs/pull/1851)
- **Status**: Draft
- **Authors**: babyblueviper1 (@babyblueviper1), Tiago Merlini (@TMerlini)

## Scope of this folder

ERC-8323 is a companion standard to ERC-8004 (Trustless Agents): a way to derive an agent
identity from a pre-existing ERC-721 a holder already owns (a PFP, a membership token, a game
character), recording permanent provenance while exposing live ownership separately and
re-checkably.

## Interfaces

| File | Role |
|------|------|
| `IAgentSourceBinding.sol` | Full interface (`0x27eba962`) — registers new agents bound to a fixed source collection (`boundCollection` / `registerWithSource`) plus the read side. |
| `IAgentSourceBindingView.sol` | Query-only subset (`0x8b3597c9`, same file) — `getSourceNFT` / `hasSourceNFT` / `isSourceNFTOwnershipValid` only, for agents that can attest source ownership without implementing registration (the canonical case: a self-sourced agent whose source *is* the agent contract itself). Independently-derived ERC-165 id, not inherited from the full interface, so it stays fixed to exactly the three functions it declares.

## Design notes

- **Provenance vs. live ownership, kept separate.** `getSourceNFT`/`SourceNFTLinked` are immutable
  facts recorded once at registration. `isSourceNFTOwnershipValid` is a live, re-checked-at-query-time
  view — never cached — so a resold source token doesn't silently keep an old holder's agent looking
  valid.
- **Non-custodial by design.** The source token is checked once via `ownerOf`, never locked, escrowed,
  or transferred.
- **Sybil-neutral on resale.** Track record never travels with the source token — a re-minted agent
  (after the source NFT changes hands) re-earns its record from zero.
- **ERC-6551 / binding-custody aware.** `isSourceNFTOwnershipValid` MUST accept any of three valid
  holders: the agent's direct owner, its canonical ERC-6551 token-bound account (pinned to the
  registry's declared implementation + salt, not "any TBA"), or the binding contract itself. A bare
  `ownerOf(source) == ownerOf(agentId)` check is non-conformant — it force-fails those patterns.
- **The full-vs-view split is an honesty boundary, not a lesser interface.** A self-sourced or
  read-only-source agent that only advertises `0x27eba962` (the full interface) while lacking
  `boundCollection`/`registerWithSource` is lying to `supportsInterface` — found as a real bug in a
  production reference (`GenesisAgentRegistry`, fixed by carving out the view-only id instead).

## ERC-165 interface ids (recomputed independently before this contribution)

```
boundCollection()                    -> 0xa72ec63c
registerWithSource(uint256)          -> 0x0bf0f897
getSourceNFT(uint256)                -> 0x8afc3f3f
hasSourceNFT(uint256)                -> 0xe08bc9f2
isSourceNFTOwnershipValid(uint256)   -> 0xe1426104

IAgentSourceBinding     = XOR(all five)        = 0x27eba962
IAgentSourceBindingView = XOR(last three only) = 0x8b3597c9
```
