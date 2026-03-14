import 'iterators'

param input: OnOrderCommands

// Collect all deliveries that has just been completed
let completedDeliveries =
  input.before.deliveries
  join right input.order.deliveries on deliveryId
  where d => d is (:not { deliveryState: 'completed' }, : {deliveryState: 'completed'})
  select (l, r) => r

// For each completed delivery, emit releaseShippingToInvoicing commands for the delivery itself (shipping product) as
// well as all the contained order lines.
from
  completedDeliveries
  select delivery =>
    from {
      effect = 'orderCommand'
      type = 'releaseShippingToInvoicing'
      deliveryId = delivery.deliveryId
    }

    from
      delivery.orderLines
      select orderLine => {
        effect = 'orderCommand'
        type = 'releaseOrderLineToInvoicing'
        orderLineId = orderLine.orderLineId
      }

    // Write to the order's activity log to inform users of what happened
    from {
      effect = 'orderCommand'
      type = 'addActivityLog'
      messageTemplate = 'Releasing delivery {deliveryNumber} to invoice due to shipment'
      dynamic = {
        deliveryNumber = delivery.deliveryNumber
      }
    }
