// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// ttl.sol : ttl token for rewards distribution
//

// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// ttl.sol : ttl token for rewards distribution

pragma solidity ^0.8.20;

import "@tide/tfund/token.sol";

contract TLLToken is TToken {
  constructor() TfundToken("tide TTL", "TTL") {}
}
