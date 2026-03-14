import 'iterators'
    
param input: OnOrderCommands | OnOrderDeleted

// Create a list of all order lines and their skus and quantities
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
    // Collect all skus before and after the current order update
    let beforeSkuMap = getSkuMap(input.before.deliveries) buffer 
    let afterSkuMap = getSkuMap(input.order.deliveries) buffer

    // Join the lists to create per-sku pairs
    from
      beforeSkuMap
      join outer afterSkuMap on key
      select link => link match
        // Unreserve skus that was either cancelled or removed from the order
        (:not nothing, :nothing|{deliveryState: 'cancelled'|'cancelledByOrder'}|{inventoryKey:nothing}) |> {
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

        // Reduce stock of skus that was delivered as well as remove reservation (if there was one)
        (:value, :{deliveryState: 'completed'}) |> {
          effect = 'messageActor'
          actorType = 'sku'
          actorId = link.right.skuNumber
          messageType = 'applyCommands'
          body = {
            commands = link.left match
              nothing |>
                // Delivery went straight to completed (no previous state)
                [{
                  type = 'setPhysicalStock'
                  inventoryKey = link.right.inventoryKey
                  quantity = link.right.quantity * -1
                  relative = true
                }]
              |>
                // Delivery was possibly reserved before, remove existing reservation
                [{
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

        // Reserve any sku that's part of an open or processing delivery
        (:value, :{deliveryState: 'open'|'processing',inventoryKey:not nothing}) |> {
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
  
  // In case of the order being deleted, remove all reservations
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

