from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
import numpy as np
import itertools
from typing import List, Tuple, Dict

class Irv_tally_circuit(Circuit):
    def __init__(self, params=None):
        super().__init__(config=params)

    def reolve_ties(self, tally, constants):
        pass

    def generate_all_rankings(self, n_cand: int) -> List[Tuple[int, ...]]:
        """
        Generates all possible partial and full rankings of n_cand candidates,
        ordered lexicographically where '-' (represented as -1) comes before any candidate.
        """
        rankings = []
        cands = list(range(n_cand))

        # Generate permutations for all possible lengths of subsets (k = 0 to n_cand)
        for k in range(n_cand + 1):
            for perm in itertools.permutations(cands, k):
                # Pad the remaining positions with -1 (which represents '-')
                padded_ranking = list(perm) + [-1] * (n_cand - k)
                rankings.append(tuple(padded_ranking))

        # Python's default tuple sorting natively handles the lexicographical 
        # requirement because -1 is less than 0, 1, 2, etc.
        rankings.sort()

        return rankings

    def generate_random_tally(self, n_cand: int, num_votes: int=100) -> Tuple[List[int], List[Tuple[int, ...]]]:
        """
        Generates a random tally array for an IRV election.

        :param n_cand: Number of candidates in the election.
        :param n_voters: Total number of cast ballots.
        :return: A tuple containing the tally array and the ordered list of rankings for reference.
        """
        rankings = self.generate_all_rankings(n_cand)
        n_rankings = len(rankings)

        # Initialize the tally array with zeros
        tally = [0] * n_rankings

        # Cast random votes
        for _ in range(num_votes):
            # Choose a random ranking index (Uniform distribution for testing purposes)
            random_index = random.randint(0, n_rankings - 1)
            tally[random_index] += 1

        return tally, rankings

    def get_removed_pos_matrix(self, n_cand: int) -> List[List[int]]:
        """
        Generates a 2D list representing the lookup matrix for IRV shifts.
        matrix[pos][cand_to_remove] gives the new position of the ranking.
        """
        rankings = self.generate_all_rankings(n_cand)

        # Reverse lookup map to quickly find the index of a ranking tuple
        ranking_to_pos = {ranking: idx for idx, ranking in enumerate(rankings)}

        matrix = []
        for pos, ranking in enumerate(rankings):
            row = []
            for cand_to_remove in range(n_cand):
                # 1. Filter out the removed candidate and empty slots (-1)
                filtered = [c for c in ranking if c != cand_to_remove and c != -1]

                # 2. Pad it back to length n_cand with -1
                padded = filtered + [-1] * (n_cand - len(filtered))

                # 3. Look up the new target index
                target_pos = ranking_to_pos[tuple(padded)]
                row.append(target_pos)

            matrix.append(row)

        # print(f"Candidate removed position mappings:\n{matrix}")
        return matrix

    def get_cand_ranked_first_positions_matrix(self, n_cand: int) -> List[List[int]]:
        """
        Generates a 2D list where the list at index 'c' contains all 
        ranking positions where candidate 'c' is ranked first.
        """
        rankings = self.generate_all_rankings(n_cand)

        # Initialize a list of empty lists for each candidate
        matrix = [[] for _ in range(n_cand)]

        for pos, ranking in enumerate(rankings):
            first_cand = ranking[0]

            # If first_cand is -1 (the completely empty ranking), we ignore it
            if first_cand != -1:
                matrix[first_cand].append(pos)

        return matrix

    def evaluate_tally(self, 
        n_cand: int,
        n_rounds: int,
        tally: List[int], 
        rankings: List[Tuple[int, ...]],
        tie_breaker_additional_data=None
    ) -> List[int]:
        """
        Evaluates an IRV election tally round by round.

        :param tally: The array of vote counts.
        :param rankings: The ordered list of ranking permutations matching the tally array.
        :param n_cand: The total number of candidates.
        :param tie_breaker: Function to resolve ties.
        :param n_rounds: Maximum number of elimination rounds. If None, runs until 1 candidate remains.
        :return: A list of 1s and 0s indicating the winning candidate(s).
        """
        active_ballots: Dict[Tuple[int, ...], int] = {}
        for count, ranking in zip(tally, rankings):
            if count > 0:
                active_ballots[ranking] = count

        active_candidates = set(range(n_cand))

        # If n_rounds is not specified, it takes at most n_cand - 1 rounds to find a winner
        max_rounds = n_rounds if n_rounds is not None and n_rounds < n_cand else (n_cand -1)
        round_num = 1

        votes_history: List[Dict[int, int]] = []

        while len(active_candidates) > 1 and round_num <= max_rounds:
            # Step 2a: Count first-choice votes
            first_choice_votes = {c: 0 for c in active_candidates}
            total_valid_votes = 0

            for ranking, votes in active_ballots.items():
                first_choice = ranking[0]
                if first_choice != -1 and first_choice in active_candidates:
                    first_choice_votes[first_choice] += votes
                    total_valid_votes += votes

            # Save this round's votes to history BEFORE tie-breaking
            # Fill non-active candidates with 0 so historical lookups don't crash
            full_round_votes = {c: first_choice_votes.get(c, 0) for c in range(n_cand)}
            votes_history.append(full_round_votes)

            # Step 2b: Check for an absolute majority
            majority_threshold = total_valid_votes / 2
            for cand, votes in first_choice_votes.items():
                if votes > majority_threshold:
                    print(f"Round {round_num}: Candidate {cand} wins with {votes} votes (>{majority_threshold} threshold).")
                    # Return indicator array with just this candidate
                    return [1 if c == cand else 0 for c in range(n_cand)]

            # Step 2c: Find the candidate(s) with the minimum votes
            min_votes = min(first_choice_votes.values())
            tied_candidates = [c for c, v in first_choice_votes.items() if v == min_votes]

            # Step 2d: Resolve ties using the injected function
            cand_to_remove = self.resolve_ties(round_num-1, tied_candidates, votes_history, tie_breaker_additional_data)
            active_candidates.remove(cand_to_remove)
            print(f"Round {round_num}: Candidate {cand_to_remove} eliminated (had {min_votes} votes). Ties resolved among: {tied_candidates}")

            # Step 2e: Edit ballots by removing the eliminated candidate and shifting
            new_ballots: Dict[Tuple[int, ...], int] = {}
            for ranking, votes in active_ballots.items():
                filtered_ranking = [c for c in ranking if c != cand_to_remove and c != -1]
                padded_ranking = filtered_ranking + [-1] * (n_cand - len(filtered_ranking))
                new_tuple = tuple(padded_ranking)

                if new_tuple not in new_ballots:
                    new_ballots[new_tuple] = 0
                new_ballots[new_tuple] += votes

            active_ballots = new_ballots
            round_num += 1

        # 3. Create the winner indicator array
        winner_array = [1 if c in active_candidates else 0 for c in range(n_cand)]

        if len(active_candidates) == 1:
            winner = list(active_candidates)[0]
            print(f"Evaluation finished: Candidate {winner} wins.")
        else:
            print(f"Evaluation finished: Max rounds ({max_rounds}) reached. Remaining candidates: {list(active_candidates)}")

        return winner_array
    
    def generate_constants(self, existing_constants):
        constants = existing_constants
        n_cand = int(self.retrieve_global_data("constants", "nCand", constants))
        rankings = self.generate_all_rankings(n_cand)
        n_rankings = len(rankings)
        getCandRemovedPos = self.get_removed_pos_matrix(n_cand)
        getFirstRankedPos = self.get_cand_ranked_first_positions_matrix(n_cand)
        constants["nRankings"] = n_rankings
        constants["getCandRemovedPos"] = getCandRemovedPos
        constants["getFirstRankedPos"] = getFirstRankedPos
        return constants
    
    