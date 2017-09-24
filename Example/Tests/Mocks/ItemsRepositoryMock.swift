//
//  ItemsRepositoryMock.swift
//  Mocky
//
//  Created by przemyslaw.wosko on 19/05/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import Mocky
import XCTest
@testable import Mocky_Example
import RxSwift

// sourcery: mock = "ItemsRepository"
class ItemsRepositoryMock: ItemsRepository, Mock {
// sourcery:inline:auto:ItemsRepositoryMock.autoMocked

    var invocations: [MethodType] = []
    var methodReturnValues: [MethodProxy] = []
    var matcher: Matcher = Matcher.default

    //MARK : ItemsRepository


    func storeItems(items: [Item]) {
        addInvocation(.storeItems__items(.value(items)))
        
    }
    
    func storeDetails(details: ItemDetails) {
        addInvocation(.storeDetails__details(.value(details)))
        
    }
    
    func storedItems() -> [Item]? {
        addInvocation(.storedItems)
        return methodReturnValue(.storedItems) as! [Item]? 
    }
    
    func storedDetails(item: Item) -> ItemDetails? {
        addInvocation(.storedDetails__item(.value(item)))
        return methodReturnValue(.storedDetails__item(.value(item))) as! ItemDetails? 
    }
    
    enum MethodType {

        case storeItems__items(Parameter<[Item]>)    
        case storeDetails__details(Parameter<ItemDetails>)    
        case storedItems    
        case storedDetails__item(Parameter<Item>)     
    
        static func compareParameters(lhs: MethodType, rhs: MethodType, matcher: Matcher) -> Bool {
            switch (lhs, rhs) {

                case (.storeItems__items(let lhsItems), .storeItems__items(let rhsItems)):  
                    guard Parameter.compare(lhs: lhsItems, rhs: rhsItems, with: matcher) else { return false }  
                    return true 
                case (.storeDetails__details(let lhsDetails), .storeDetails__details(let rhsDetails)):  
                    guard Parameter.compare(lhs: lhsDetails, rhs: rhsDetails, with: matcher) else { return false }  
                    return true 
                case (.storedItems, .storedItems):  
                    return true 
                case (.storedDetails__item(let lhsItem), .storedDetails__item(let rhsItem)):  
                    guard Parameter.compare(lhs: lhsItem, rhs: rhsItem, with: matcher) else { return false }  
                    return true 
                default: return false   
            }
        }
    }

    struct MethodProxy {
        var method: MethodType 
        var returns: Any? 

        static func storeItems(items: Parameter<[Item]>, willReturn: Void) -> MethodProxy {
            return MethodProxy(method: .storeItems__items(items), returns: willReturn)
        }
        
        static func storeDetails(details: Parameter<ItemDetails>, willReturn: Void) -> MethodProxy {
            return MethodProxy(method: .storeDetails__details(details), returns: willReturn)
        }
        
        static func storedItems(willReturn: [Item]?) -> MethodProxy {
            return MethodProxy(method: .storedItems, returns: willReturn)
        }
        
        static func storedDetails(item: Parameter<Item>, willReturn: ItemDetails?) -> MethodProxy {
            return MethodProxy(method: .storedDetails__item(item), returns: willReturn)
        }
         
    }

    public func methodReturnValue(_ method: MethodType) -> Any? {
        let matched = methodReturnValues.reversed().first(where: { proxy -> Bool in
            return MethodType.compareParameters(lhs: proxy.method, rhs: method, matcher: matcher)
        })

        return matched?.returns
    }

    public func verify(_ method: MethodType, count: UInt = 1, file: StaticString = #file, line: UInt = #line) {
        let invocations = matchingCalls(method)
        XCTAssert(invocations.count == Int(count), "Expeced: \(count) invocations of `\(method)`, but was: \(invocations.count)", file: file, line: line)
    }

    public func addInvocation(_ call: MethodType) {
        invocations.append(call)
    }

    public func matchingCalls(_ method: MethodType) -> [MethodType] {
        let matchingInvocations = invocations.filter({ (call) -> Bool in
            return MethodType.compareParameters(lhs: call, rhs: method, matcher: matcher)
        })
        return matchingInvocations
    }
    
    public func given(_ method: MethodProxy) {
        methodReturnValues.append(method)
    }
    
// sourcery:end
}
