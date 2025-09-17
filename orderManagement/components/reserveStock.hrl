import 'iterators'
    
param input: OnOrderCommands | OnOrderDeleted

let getSkuMap(deliveries: [Delivery]) =>
  deliveries
  select d =>
    d.orderLines
    select ol =>
      ol.skus
      select sku => {
        key = $'{ol.orderLineId}_{sku.skuNumber}'
        orderLineId = ol.orderLineId
        inventoryKey = d.inventoryKey
        inventoryDate = d.inventoryDate
        skuNumber = sku.skuNumber
        quantity = sku.totalQuantity
        deliveryState = d.deliveryState
      }
    flatten
  flatten



from input match
  OnOrderCommands |>
    let beforeSkuMap = getSkuMap(input.before.deliveries) buffer 
    let afterSkuMap = getSkuMap(input.order.deliveries) buffer

    from
      beforeSkuMap
      join outer afterSkuMap on key
      select link => link match
        (:not nothing, :nothing|{deliveryState: 'cancelled'|'cancelledByOrder'}) |> {
          effect = 'messageActor'
          actorType = 'sku'
          actorId = link.left.skuNumber
          messageType = 'applyCommands'
          body = {
            commands = [{
              type = 'unreserve'
              orderId = input.order.orderId
              orderLineId = link.left.orderLineId
            }]
          }
        }
        (:not {deliveryState: 'completed'}, :{deliveryState: 'completed'}) |> {
          effect = 'messageActor'
          actorType = 'sku'
          actorId = link.left.skuNumber
          messageType = 'applyCommands'
          body = {
            commands = [{
              type = 'unreserve'
              orderId = input.order.orderId
              orderLineId = link.left.orderLineId
            },{
              type = 'setPhysicalStock'
              inventoryKey = link.right.inventoryKey
              quantity = link.right.quantity * -1
              relative = true
            }]
          }
        }
        (:value, :{deliveryState: 'open'|'processing'}) |> {
          effect = 'messageActor'
          actorType = 'sku'
          actorId = link.right.skuNumber
          messageType = 'applyCommands'
          body = {
            commands = [{
              type = 'reserve'
              orderId = input.order.orderId
              orderLineId = link.right.orderLineId
              inventoryKey = link.right.inventoryKey
              inventoryDate = link.right.inventoryDate
              quantity = link.right.quantity
            }]
          }
        }
  OnOrderDeleted |>
    getSkuMap(input.order.deliveries)
    buffer
    select sku => {
      effect = 'messageActor'
      actorType = 'sku'
      actorId = sku.skuNumber
      messageType = 'applyCommands'
      body = {
        commands = [{
          type = 'unreserve'
          orderId = input.order.orderId
          orderLineId = sku.orderLineId
        }]
      }
    }

