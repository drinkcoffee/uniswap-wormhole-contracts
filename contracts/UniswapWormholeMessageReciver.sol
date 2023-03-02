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
    string public name = "Uniswap Wormhole Message Receiver";

    address public owner;
    bytes32 public messageSender;

    mapping(bytes32 => bool) public processedMessages;

    IWormhole private immutable wormhole;

    constructor(address bridgeAddress, bytes32 _messageSender) {
        wormhole = IWormhole(bridgeAddress);
        messageSender = _messageSender;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "sender not owner");
        _;
    }

    function receiveMessage(bytes[] memory whMessages) public {
        (Structs.VM memory vm, bool valid, string memory reason) = wormhole.parseAndVerifyVM(whMessages[0]);

        //validate
        require(valid, reason);
        
        // Ensure the emitterAddress of this VAA is the Uniswap message sender
        require(messageSender == vm.emitterAddress, "Invalid Emitter Address!");

        // Ensure the emitterChainId is Ethereum to prevent impersonation
        require(2 == vm.emitterChainId , "Invalid Emmiter Chain");

        //verify destination
        (address[] memory targets, uint256[] memory values, bytes[] memory datas, address messageReceiver) = abi.decode(vm.payload,(address[], uint256[], bytes[], address));
        require (messageReceiver == address(this), "Message not for this dest");

        // replay protection
        require(!processedMessages[vm.hash], "Message already processed");
        processedMessages[vm.hash] = true;

        //execute message
        require(targets.length == datas.length && targets.length == values.length, 'Inconsistent argument lengths');
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call{value: values[i]}(datas[i]);
            require(success, 'Sub-call failed');
        }
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
