pragma circom 2.2.1;

include "multi_vote_voting.circom";

/**
* Assert that in a ballot with n_votes votes, each vote is at most maxVotesCand and that the sum of all votes is at most maxChoices.
* As an example for an additional rule, we also enforce that the product of the second and third entry in the ballot equals the first one.
* Requires a list of length n_Votes >= 3.
*/
template Multi_vote_with_rules_voting(bits_votes, n_votes, max_votes_cand, max_choices) {
    input signal ballot[n_votes];

    component assert_multi_vote = Multi_vote_voting(bits_votes, n_votes, max_votes_cand, max_choices);
    assert_multi_vote.ballot <== ballot;

    ballot[1] * ballot[2] === ballot[0];
}
