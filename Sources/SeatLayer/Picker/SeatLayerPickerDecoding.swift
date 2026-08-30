import Foundation

/// Tolerant on additive fields and malformed optional entries. The four v1
/// identity fields are the only reason a snapshot is rejected as a whole.
func decodeSeatLayerPickerSnapshot(_ value: JSONValue?) -> SeatLayerPickerSnapshot? {
    guard let raw = value,
          let root = raw.objectValue,
          root["schema"]?.stringValue == seatLayerPickerSnapshotSchema,
          let sessionId = nonEmpty(root["sessionId"]?.stringValue),
          let revision = exactInteger(root["revision"]),
          let event = decodePickerEvent(root["event"]) else {
        return nil
    }

    let catalog = root["catalog"]?.objectValue
    let selectionNode = root["selection"]?.objectValue
    let cart = root["cart"]?.objectValue
    let hold = root["hold"]?.objectValue
    let access = root["access"]?.objectValue
    let cartLines = decodeList(cart?["items"] ?? cart?["lines"], using: decodeCartLine)
    let selected = decodeCodableList(selectionNode?["seats"], as: SelectedSeat.self)
    let lineTotal = cartLines.reduce(0) { $0 + $1.total }

    return SeatLayerPickerSnapshot(
        schema: seatLayerPickerSnapshotSchema,
        sessionId: sessionId,
        revision: revision,
        event: event,
        branding: decodeBranding(root["branding"]),
        categories: decodeList(catalog?["categories"], using: decodeCategory),
        zones: decodeList(catalog?["zones"], using: decodeZone),
        sections: decodeList(catalog?["sections"], using: decodeSection),
        generalAdmissionAreas: decodeCodableList(catalog?["gaAreas"], as: GAArea.self),
        bestAvailableZones: decodeList(
            catalog?["bestAvailableZones"],
            using: decodeZone
        ),
        map: decodeMap(root["map"]),
        selection: selected,
        selectionValidity: try? selectionNode?["validity"]?.decode(SelectionValidity.self),
        maxSelection: exactInteger(selectionNode?["maxSelection"]) ?? 10,
        ticketCount: exactInteger(cart?["quantity"]) ?? selected.count,
        cartLines: cartLines,
        cartTotal: finiteDouble(cart?["total"]) ?? lineTotal,
        currency: cart?["currency"]?.stringValue ?? event.currency,
        hold: SeatLayerPickerHold(
            active: hold?["active"]?.boolValue ?? false,
            expiresAt: finiteDouble(hold?["expiresAt"]),
            owner: hold?["ownership"]?.stringValue
        ),
        accessConfigured: access?["configured"]?.boolValue ?? false,
        accessStatus: access?["status"]?.stringValue ?? "public",
        accessReason: access?["reason"]?.stringValue,
        capabilities: enabledCapabilities(root["features"]),
        raw: raw
    )
}

func decodeSeatLayerPickerCheckoutHandoff(
    _ value: JSONValue?
) -> SeatLayerPickerCheckoutHandoff? {
    guard let item = value?.objectValue,
          let holdId = nonEmpty(item["holdId"]?.stringValue),
          let expiresAt = finiteDouble(item["expiresAt"]) else {
        return nil
    }
    let lines = decodeList(item["lineItems"], using: decodeCartLine)
    return SeatLayerPickerCheckoutHandoff(
        holdId: holdId,
        expiresAt: expiresAt,
        currency: item["currency"]?.stringValue ?? lines.first?.currency ?? "USD",
        lineItems: lines,
        total: finiteDouble(item["total"]) ?? lines.reduce(0) { $0 + $1.total }
    )
}

func decodeSeatLayerSeatView(_ value: JSONValue?) -> SeatLayerSeatView? {
    guard let item = value?.objectValue else { return nil }
    return SeatLayerSeatView(
        seatId: item["seatId"]?.stringValue,
        title: item["title"]?.stringValue,
        caption: item["caption"]?.stringValue,
        badge: item["badge"]?.stringValue,
        real: item["real"]?.boolValue ?? false,
        generated: item["generated"]?.boolValue ?? false,
        dragHint: item["dragHint"]?.stringValue
    )
}

private func decodePickerEvent(_ value: JSONValue?) -> SeatLayerPickerEventDetails? {
    guard let item = value?.objectValue,
          let key = nonEmpty(item["key"]?.stringValue) else { return nil }
    let rawMode = item["mode"]?.stringValue ?? "live"
    return SeatLayerPickerEventDetails(
        key: key,
        name: item["name"]?.stringValue ?? key,
        mode: EventMode(rawValue: rawMode) ?? .unknown(rawMode),
        currency: item["currency"]?.stringValue ?? "USD",
        venue: item["venue"]?.stringValue,
        startsAt: finiteDouble(item["startsAt"]),
        timezone: item["timezone"]?.stringValue,
        locale: item["locale"]?.stringValue,
        posterURL: item["posterUrl"]?.stringValue,
        salesClosed: item["salesClosed"]?.boolValue ?? false
    )
}

private func decodeBranding(_ value: JSONValue?) -> SeatLayerPickerBranding {
    let item = value?.objectValue
    let tokens = item?["tokens"]?.objectValue
    return SeatLayerPickerBranding(
        brandName: item?["brandName"]?.stringValue,
        logoURL: item?["logoUrl"]?.stringValue,
        attributionRequired: item?["attributionRequired"]?.boolValue ?? true,
        accent: item?["accent"]?.stringValue ?? tokens?["accent"]?.stringValue,
        accentInk: item?["accentInk"]?.stringValue ?? tokens?["accentInk"]?.stringValue,
        background: item?["background"]?.stringValue ?? tokens?["background"]?.stringValue,
        surface: tokens?["surface"]?.stringValue,
        text: item?["textColor"]?.stringValue ?? tokens?["text"]?.stringValue,
        muted: tokens?["muted"]?.stringValue,
        line: tokens?["line"]?.stringValue,
        fontFamily: tokens?["fontFamily"]?.stringValue,
        radius: finiteDouble(tokens?["radius"])
    )
}

private func decodeCategory(_ value: JSONValue) -> SeatLayerPickerCategory? {
    guard let item = value.objectValue,
          let key = nonEmpty(item["key"]?.stringValue) else { return nil }
    let tiers = decodeCodableList(item["tiers"], as: CategoryTier.self)
    let prices = tiers.map(\.price)
    let base = finiteDouble(item["price"]) ?? prices.first ?? 0
    return SeatLayerPickerCategory(
        key: key,
        label: item["label"]?.stringValue ?? key,
        color: item["color"]?.stringValue ?? "#6e7bff",
        priceMin: finiteDouble(item["priceMin"]) ?? prices.min() ?? base,
        priceMax: finiteDouble(item["priceMax"]) ?? prices.max() ?? base,
        available: exactInteger(item["available"]) ?? 0,
        notForSale: item["notForSale"]?.boolValue ?? false,
        tiers: tiers
    )
}

private func decodeZone(_ value: JSONValue) -> SeatLayerPickerZone? {
    guard let item = value.objectValue,
          let id = nonEmpty(item["id"]?.stringValue) else { return nil }
    return SeatLayerPickerZone(
        id: id,
        label: item["label"]?.stringValue ?? id,
        color: item["color"]?.stringValue
    )
}

private func decodeSection(_ value: JSONValue) -> SeatLayerPickerSectionSummary? {
    guard let item = value.objectValue,
          let id = nonEmpty(item["id"]?.stringValue) else { return nil }
    return SeatLayerPickerSectionSummary(
        id: id,
        label: item["label"]?.stringValue ?? id,
        displayLabel: item["displayLabel"]?.stringValue,
        zoneId: item["zoneId"]?.stringValue,
        zoneLabel: item["zoneLabel"]?.stringValue,
        entrance: item["entrance"]?.stringValue,
        color: item["color"]?.stringValue,
        dominantCategoryKey: item["dominantCategoryKey"]?.stringValue,
        seatsLeft: exactInteger(item["seatsLeft"]),
        priceMin: finiteDouble(item["priceMin"]),
        priceMax: finiteDouble(item["priceMax"])
    )
}

private func decodeCartLine(_ value: JSONValue) -> SeatLayerPickerCartLine? {
    guard let item = value.objectValue,
          let label = nonEmpty(item["label"]?.stringValue) else { return nil }
    let objectId = item["objectId"]?.stringValue ?? label
    return SeatLayerPickerCartLine(
        lineKey: item["lineKey"]?.stringValue ?? item["key"]?.stringValue ?? objectId,
        label: label,
        displayLabel: item["displayLabel"]?.stringValue,
        displayType: item["displayType"]?.stringValue,
        objectId: objectId,
        objectType: item["objectType"]?.stringValue ?? "seat",
        categoryKey: item["categoryKey"]?.stringValue ?? "",
        tierId: item["tierId"]?.stringValue,
        unitPrice: finiteDouble(item["unitPrice"]) ?? 0,
        currency: item["currency"]?.stringValue ?? "USD",
        quantity: exactInteger(item["quantity"]) ?? 1,
        seatId: item["seatId"]?.stringValue,
        sectionLabel: item["sectionLabel"]?.stringValue,
        rowLabel: item["rowLabel"]?.stringValue,
        seatNumber: item["seatNumber"]?.stringValue
    )
}

private func decodeMap(_ value: JSONValue?) -> SeatLayerPickerMapState {
    let item = value?.objectValue
    return SeatLayerPickerMapState(
        rung: item?["rung"]?.stringValue ?? "zones",
        viewMode: item?["viewMode"]?.stringValue ?? item?["projection"]?.stringValue ?? "flat",
        buyerView: item?["buyerView"]?.stringValue ?? "map",
        view3DNavigationMode: item?["view3dNavigationMode"]?.stringValue ?? "orbit",
        view3DTargetSeatId: item?["view3dTargetSeatId"]?.stringValue,
        activeFloorId: item?["activeFloorId"]?.stringValue ?? item?["floorId"]?.stringValue,
        focusedSectionId: item?["focusedSectionId"]?.stringValue,
        focusedSection: item?["focusedSection"].flatMap(decodeSection),
        colorblindSafe: item?["colorblindSafe"]?.boolValue ?? false,
        hideLimitedView: item?["hideLimitedView"]?.boolValue ?? false,
        canZoomIn: item?["canZoomIn"]?.boolValue ?? true,
        canZoomOut: item?["canZoomOut"]?.boolValue ?? true,
        categoryFilter: uniqueStrings(item?["categoryFilter"]),
        accessibilityFilter: uniqueStrings(item?["accessibilityFilter"]),
        accessNeeds: uniqueAccessNeeds(item?["accessNeeds"]),
        floors: decodeList(item?["floors"], using: decodeFloor),
        floorMode: item?["floorMode"]?.stringValue,
        floorLabelStyle: item?["floorLabelStyle"]?.stringValue,
        viewportInsets: decodeInsets(item?["viewportInsets"])
    )
}

private func decodeFloor(_ value: JSONValue) -> SeatLayerPickerFloorInfo? {
    guard let item = value.objectValue,
          let id = nonEmpty(item["id"]?.stringValue),
          let name = nonEmpty(item["name"]?.stringValue) else { return nil }
    return SeatLayerPickerFloorInfo(id: id, name: name, level: exactInteger(item["level"]))
}

private func decodeInsets(_ value: JSONValue?) -> SeatLayerPickerViewportInsets? {
    guard let item = value?.objectValue else { return nil }
    return SeatLayerPickerViewportInsets(
        top: max(0, finiteDouble(item["top"]) ?? 0),
        right: max(0, finiteDouble(item["right"]) ?? 0),
        bottom: max(0, finiteDouble(item["bottom"]) ?? 0),
        left: max(0, finiteDouble(item["left"]) ?? 0)
    )
}

private func uniqueAccessNeeds(_ value: JSONValue?) -> [SeatLayerPickerAccessNeed] {
    var seen = Set<String>()
    return decodeList(value) { entry in
        guard let item = entry.objectValue,
              let rawKey = item["key"]?.stringValue,
              let key = nonEmpty(rawKey.trimmingCharacters(in: .whitespacesAndNewlines)),
              seen.insert(key).inserted else { return nil }
        return SeatLayerPickerAccessNeed(
            key: key,
            count: max(0, exactInteger(item["count"]) ?? 0)
        )
    }
}

private func enabledCapabilities(_ value: JSONValue?) -> Set<String> {
    guard let fields = value?.objectValue else { return [] }
    return Set(fields.compactMap { key, value in
        if value.boolValue == true { return key }
        if let items = value.arrayValue, !items.isEmpty { return key }
        return nil
    })
}

private func uniqueStrings(_ value: JSONValue?) -> [String] {
    var seen = Set<String>()
    return (value?.arrayValue ?? []).compactMap { item in
        guard let string = item.stringValue, seen.insert(string).inserted else { return nil }
        return string
    }
}

private func decodeList<T>(
    _ value: JSONValue?,
    using decode: (JSONValue) -> T?
) -> [T] {
    (value?.arrayValue ?? []).compactMap(decode)
}

private func decodeCodableList<T: Decodable>(
    _ value: JSONValue?,
    as type: T.Type
) -> [T] {
    (value?.arrayValue ?? []).compactMap { try? $0.decode(type) }
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}

private func exactInteger(_ value: JSONValue?) -> Int? {
    switch value {
    case .int(let number):
        return number
    case .double(let number) where number.isFinite && number.rounded() == number:
        return Int(exactly: number)
    default:
        return nil
    }
}

private func finiteDouble(_ value: JSONValue?) -> Double? {
    guard let number = value?.doubleValue, number.isFinite else { return nil }
    return number
}
