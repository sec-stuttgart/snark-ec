from proving_pipeline.circuit_wrapper.circuit import Circuit
import random

class Compute_smith_set(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def generate_random_tally(self, n, num_voters=100):
        """
        Generates a random n x n preference tally matrix for testing.

        Args:
            n (int): The number of candidates.
            num_voters (int): Total number of voters in the election.

        Returns:
            list of list of int: An n x n tally matrix where tally[i][j] + tally[j][i] = num_voters.
        """
        if n <= 0:
            return []

        # Initialize an n x n matrix with zeros
        tally = [[0] * n for _ in range(n)]

        for i in range(n):
            for j in range(i + 1, n):
                # Randomly split the votes between candidate i and candidate j
                votes_for_i = random.randint(0, num_voters)
                votes_for_j = num_voters - votes_for_i

                # Assign the preferences
                tally[i][j] = votes_for_i
                tally[j][i] = votes_for_j

        return tally

    def generate_tiered_tally(self, n, num_voters=100):
        """
        Generates a preference tally where the Smith set is guaranteed 
        to be greater than 1 but less than n (requires n >= 4).
        """
        if n < 4:
            raise ValueError("Need at least 4 candidates to have a Smith set size strictly between 1 and n.")

        tally = [[0] * n for _ in range(n)]

        # 1. Decide the size of the Smith set (at least 3 for a cycle, less than n)
        k = random.randint(3, n - 1)

        # 2. Randomly select which candidates make up the Smith set
        candidates = list(range(n))
        random.shuffle(candidates)
        smith_members = candidates[:k]
        losers = candidates[k:]

        def set_winner(winner, loser):
            """Helper to assign votes so the winner strictly beats the loser."""
            win_votes = random.randint((num_voters // 2) + 1, num_voters)
            # Prevent an exact tie if num_voters is even
            if win_votes * 2 == num_voters:
                win_votes += 1
            tally[winner][loser] = win_votes
            tally[loser][winner] = num_voters - win_votes

        # 3. Populate the matrix
        for i in range(n):
            for j in range(i + 1, n):
                in_smith_i = i in smith_members
                in_smith_j = j in smith_members

                # Smith members ALWAYS beat losers
                if in_smith_i and not in_smith_j:
                    set_winner(i, j)
                elif in_smith_j and not in_smith_i:
                    set_winner(j, i)
                else:
                    # Both in Smith or both in Losers: completely random
                    votes = random.randint(0, num_voters)
                    tally[i][j] = votes
                    tally[j][i] = num_voters - votes

        # 4. Guarantee a cycle within the Smith set to prevent a Condorcet winner
        # We do this by forcing smith_members[x] to beat smith_members[x+1]
        for x in range(k):
            winner = smith_members[x]
            loser = smith_members[(x + 1) % k]
            set_winner(winner, loser)

        return tally


    def compute_smith_set(self, tally):
        """
        Computes the Smith set from an n x n preference tally matrix.

        Args:
            tally (list of list of int): tally[i][j] = m means m voters prefer i over j.

        Returns:
            list of int: out[k] = 1 if candidate k is in the Smith set, else 0.
        """
        n = len(tally)
        if n == 0:
            return []

        # Step 1: Initialize the reachability matrix.
        # reach[i][j] is True if candidate i beats or ties candidate j directly.
        reach = [[False] * n for _ in range(n)]

        for i in range(n):
            for j in range(n):
                if tally[i][j] > tally[j][i]:
                    reach[i][j] = True

        # Step 2: Compute transitive closure using the Floyd-Warshall algorithm.
        # If i can reach k, and k can reach j, then i can reach j.
        for k in range(n):
            for i in range(n):
                if reach[i][k]:  # Minor optimization: only loop if i can reach k
                    for j in range(n):
                        if reach[k][j]:
                            reach[i][j] = True

        # Step 3: Identify the Smith Set.
        # A candidate is in the Smith set if and only if they can reach ALL other candidates.
        out = [0] * n
        for i in range(n):
            # all() checks if reach[i][j] is True for every j
            if all(reach[i][j] for j in range(n)):
                out[i] = 1

        return out

    def generate_input(self, existing_input, constants):
        input = {}
        n = int(self.retrieve_global_data("constants", "n", constants))
        tally = self.generate_tiered_tally(n)
        smith_set = self.compute_smith_set(tally)
        linear_tally = []
        for row in tally:
            linear_tally += row

        input["linear_tally"] = linear_tally
        input["test_out"] = smith_set

        print(f"Tally: {tally}")
        print(f"Linear Tally: {linear_tally}")
        print(f"Smith Set: {smith_set}")

        return input

    def generate_constants(self, existing_constants):
        constants = {}
        n = int(self.retrieve_global_data("constants", "n", existing_constants))
        if not n:
            n = 10
        constants["bits"] = 32
        constants["n"] = n
        constants["n_squared"] = n*n

        return constants