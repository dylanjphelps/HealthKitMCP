// HealthKitMCP/Health/Models.swift
import Foundation

func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    return String(decoding: data, as: UTF8.self)
}
