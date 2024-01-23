import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import { List, Sold } from "../generated/NFTMarketWithList/NFTMarketWithList"

export function createListEvent(
  tokenId: BigInt,
  from: Address,
  price: BigInt
): List {
  let listEvent = changetype<List>(newMockEvent())

  listEvent.parameters = new Array()

  listEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  listEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  listEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )

  return listEvent
}

export function createSoldEvent(
  tokenId: BigInt,
  from: Address,
  to: Address,
  price: BigInt
): Sold {
  let soldEvent = changetype<Sold>(newMockEvent())

  soldEvent.parameters = new Array()

  soldEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  soldEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  soldEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  soldEvent.parameters.push(
    new ethereum.EventParam("price", ethereum.Value.fromUnsignedBigInt(price))
  )

  return soldEvent
}
