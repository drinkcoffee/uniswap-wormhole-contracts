# Possible test cases

Out of scope / not to be tested

* The Wormhole Bridge message parsing and verification is assumed to work perfectly.


We need to test Happy cases:

* one WH message, one function call)
* one WH message, two function calls
* one WH message, ten function calls
* one WH message, one function call, the application code reverts the function call, then, within the timeout, the WH message is resubmitted. This time, the application code does not revert the function call.

We need to test Sad cases:

* Sad case: two WH messages.
* Sad case: zero WH messages.
* Sad case: one WH message, zero function calls.
* Sad case: one WH message, one function call, the function call reverts.
* Sad case: Replay prevention: one WH message, one function call; Submit the message. First time passes. Submit again. Second time fails.
* Sad case: Reentrancy prevention: one WH message, one function call; the application code calls back to receive message function. This should fail.
* Sad case: incorrect emitter address.
* Sad case: incorrect source chain.
* Sad case: incorrect target contract.
* Sad case: target and value array lengths don't match.
* Sad case: target and data array lengths don't match.
* Sad case: value and data array lengths don't match.
* Sad case: message submitted after time-out.

