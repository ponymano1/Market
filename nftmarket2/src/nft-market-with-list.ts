import {
  List as ListEvent,
  Sold as SoldEvent
} from "../generated/NFTMarketWithList/NFTMarketWithList"
import { List, Sold } from "../generated/schema"

export function handleList(event: ListEvent): void {
  let entity = new List(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenId = event.params.tokenId
  entity.from = event.params.from
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSold(event: SoldEvent): void {
  let entity = new Sold(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.tokenId = event.params.tokenId
  entity.from = event.params.from
  entity.to = event.params.to
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
