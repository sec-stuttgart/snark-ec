# ZK-SNARKS for Ballot Validity

Circom implementation of Circuits for generating proofs of ballot validity and tally hiding for ballots encrypted with Exponential ElGamal (EEG) or commited with Pedersen Vector Commitments (PVC).
Commitment and Encryption Schemes are instantiated over SW Curves utilizing an optimized Exponentiation Circuit for constant bases.

## Supported election types (Ballot Validity)

- Single-Vote
- Multi-Vote
- Pointlist-Borda
- Borda Tournament Style (BTS)
- Condorcet
- Majority Judgment

## Supported result functions (Tally Hiding)

- Best $n$
- Threshold
- Most Votes
- IRV (using NSW tie breaker)
- Smith Set (for Condorcet ballots)
- Majority Judgement (Median and full Evaluation)

To install the required dependencies and benchmark our implementation, please follow the instructions in `QuickStart.md`.