//
//  Calculator.swift
//  Keyboard Pro
//
//  A tiny calculator for the suggestion bar: type "4+5" and the bar shows "= 9".
//  Handles + - * / x × ÷ ^ % and brackets. Written by hand (no NSExpression,
//  which can crash the keyboard on odd input).
//

import Foundation

enum Calculator {
    struct Answer {
        let result: String        // "9"
        let deleteCount: Int      // characters to remove before inserting (0 when the user typed "=")
    }

    /// Looks at the text just before the cursor and, if it ends with a sum, returns the answer.
    static func answer(forTextBefore text: String) -> Answer? {
        var chars = Array(text.suffix(80))
        let windowCount = chars.count
        var typedEquals = false
        if chars.last == "=" {
            typedEquals = true
            chars.removeLast()
        }
        while chars.last == " " { chars.removeLast() }
        guard !chars.isEmpty else { return nil }

        // Walk back over everything that can be part of a sum.
        var start = chars.count
        while start > 0 {
            let c = chars[start - 1]
            if c.isASCII && c.isNumber || "+-*/×÷^%().".contains(c) || c == " " {
                start -= 1
            } else if c == "x" || c == "X" {
                // "x" counts as times only between numbers: "4x5", not "box".
                let left = start >= 2 ? chars[start - 2] : nil
                let right = start < chars.count ? chars[start] : nil
                let leftOK = left.map { $0.isNumber || $0 == " " || $0 == ")" } ?? false
                let rightOK = right.map { $0.isNumber || $0 == " " || $0 == "(" || $0 == "." } ?? false
                if leftOK && rightOK { start -= 1 } else { break }
            } else {
                break
            }
        }
        while start < chars.count, chars[start] == " " { start += 1 }
        guard start < chars.count else { return nil }
        // Not part of a word or code like "mp3+4".
        if start > 0, chars[start - 1].isLetter { return nil }

        let expression = Array(chars[start...])
        var parser = Parser(expression)
        guard let value = parser.parse(), parser.usedOperator, value.isFinite else { return nil }

        // Spaces and "=" after the sum are removed with it unless the user already typed "=".
        let deleteCount = typedEquals ? 0 : windowCount - start
        return Answer(result: format(value), deleteCount: deleteCount)
    }

    private static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        var s = String(format: "%.3f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s == "-0" ? "0" : s
    }

    /// Recursive-descent parser: expr = term (+|- term)*, term = power (*|/ power)*,
    /// power = unary (^ power)?, unary = -unary | postfix, postfix = atom %*.
    private struct Parser {
        let c: [Character]
        var i = 0
        var usedOperator = false

        init(_ chars: [Character]) { c = chars }

        mutating func parse() -> Double? {
            guard let v = expr(), peek() == nil else { return nil }
            return v
        }

        mutating func peek() -> Character? {
            while i < c.count, c[i] == " " { i += 1 }
            return i < c.count ? c[i] : nil
        }

        mutating func expr() -> Double? {
            guard var v = term() else { return nil }
            while let ch = peek(), ch == "+" || ch == "-" {
                i += 1
                guard let r = term() else { return nil }
                usedOperator = true
                v = ch == "+" ? v + r : v - r
            }
            return v
        }

        mutating func term() -> Double? {
            guard var v = power() else { return nil }
            while let ch = peek(), "*/×÷xX".contains(ch) {
                i += 1
                guard let r = power() else { return nil }
                usedOperator = true
                if ch == "/" || ch == "÷" {
                    if r == 0 { return nil }
                    v /= r
                } else {
                    v *= r
                }
            }
            return v
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if peek() == "^" {
                i += 1
                guard let exp = power() else { return nil }
                usedOperator = true
                let r = pow(base, exp)
                return r.isFinite ? r : nil
            }
            return base
        }

        mutating func unary() -> Double? {
            if peek() == "-" {
                i += 1
                return unary().map { -$0 }
            }
            if peek() == "+" {
                i += 1
                return unary()
            }
            guard var v = atom() else { return nil }
            while peek() == "%" {
                i += 1
                usedOperator = true
                v /= 100
            }
            return v
        }

        mutating func atom() -> Double? {
            guard let ch = peek() else { return nil }
            if ch == "(" {
                i += 1
                guard let v = expr(), peek() == ")" else { return nil }
                i += 1
                return v
            }
            var digits = ""
            while i < c.count, c[i].isASCII, c[i].isNumber || c[i] == "." {
                digits.append(c[i])
                i += 1
            }
            guard !digits.isEmpty, digits.filter({ $0 == "." }).count <= 1 else { return nil }
            return Double(digits)
        }
    }
}
