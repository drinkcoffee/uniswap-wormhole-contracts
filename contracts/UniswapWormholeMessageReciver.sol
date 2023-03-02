/**
 * Copyright Uniswap Foundation 2023
 * 
 * This code is based on code deployed here: https://bscscan.com/address/0x3ee84fFaC05E05907E6AC89921f000aE966De001#code 
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
 * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
pragma solidity ^0.8.9;
import "./Structs.sol";

interface IWormhole {
    function parseAndVerifyVM(bytes calldata encodedVM) external view returns (Structs.VM memory vm, bool valid, string memory reason);
}

contract UniswapWormholeMessageReceiver {
    string public name = "Uniswap Wormhole Message ReceiverV2";

    // Wormhole chain number for Ethereum
    uint256 constant ETHERUM = 2;

    // Message timeout in seconds: Time out needs to account for:
    //  Finality time on source chain.
    //  Time for Wormhole validators to sign and make VAA available to relayers.
    //  Time to relay VAA to the target chain.
    //  Congestion on target chain leading to delayed inclusion of transaction in target chain.
    // Have the value set to one hour.
    // Note that there is no way to alter this hard coded value. Including such a feature
    // would require some governance structure and some minumum and maximum values.
    uint256 constant MESSAGE_TIME_OUT_SECONDS = 60 * 60;

    // Address of Uniswap Workhole Sender contract on Ethereum.
    bytes32 public messageSender;

    // Mapping (message hash -> bool) indicating a message has already been successfully processed.
    mapping(bytes32 => bool) public processedMessages;

    // Address of Wormhole contract on this chain. Used to parse and verify messages.
    IWormhole private immutable wormhole;

    /**
     * @param _bridgeAddress Address of Wormhole bridge contract on this chain.
     * @param _messageSender Address of Uniswap Wormhole Message Sender on sending chain.
     */
    constructor(address _bridgeAddress, bytes32 _messageSender) {
        wormhole = IWormhole(_bridgeAddress);
        messageSender = _messageSender;
    }


    /**
     * @param _whMessages Wormhole messages relayed from a source chain.
     */
    function receiveMessage(bytes[] memory _whMessages) public {
        require(_whMessages.length == 1, "Only one message at a time please");
        (Structs.VM memory vm, bool valid, string memory reason) = wormhole.parseAndVerifyVM(_whMessages[0]);

        //validate
        require(valid, reason);
        
        // Ensure the emitterAddress of this VAA is the Uniswap message sender
        require(messageSender == vm.emitterAddress, "Invalid Emitter Address!");

        // Ensure the emitterChainId is Ethereum to prevent impersonation
        require(ETHERUM == vm.emitterChainId , "Invalid Emmiter Chain");

        // Verify destination
        (address[] memory targets, uint256[] memory values, bytes[] memory datas, address messageReceiver) = abi.decode(vm.payload,(address[], uint256[], bytes[], address));
        require (messageReceiver == address(this), "Message not for this dest");

        // Replay and re-entrancy protection.
        require(!processedMessages[vm.hash], "Message already processed");
        processedMessages[vm.hash] = true;

        // Don't allow old messages to be processed.
        require(vm.timestamp + MESSAGE_TIME_OUT_SECONDS < block.timestamp, "Message too old");

        // Check that the target, data, and values arrays are the same length.
        require(targets.length == datas.length && targets.length == values.length, 'Inconsistent argument lengths');

        // Provide an error if a message was accidentally submitted with no function calls.
        require(targets.length != 0, 'No functions to call');

        // Execute all of the function calls in a message.
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call{value: values[i]}(datas[i]);
            require(success, 'Sub-call failed');
        }
    }
}
