//
//  CategoryService.swift
//  CoreVPN
//
//  节点分类接口
//

import Foundation

final class CategoryService {
    
    static let shared = CategoryService()
    
    private init() {}
    
    /// 拉取节点分类列表
    func fetchCategories(completion: @escaping (Result<[CategoryGroup], Error>) -> Void) {
        let endpoint = APIEndpoint(path: "/graphql/query/categories")
        
        debugPrint("[Request] 开始请求节点分类")
        
        APIRequestExecutor.shared.performRequest(endpoint: endpoint) { result in
            switch result {
            case .success(let data):
                let text = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
                debugPrint("[Request] 节点分类请求成功，响应：\(text)")
                
                guard RequestUtils.validateJsonString(text) else {
                    let error = NSError(domain: "CategoryService",
                                        code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: "Response is not valid JSON"])
                    completion(.failure(error))
                    return
                }
                
                guard let response = try? JSONDecoder().decode(CategoryResponse.self, from: data) else {
                    let error = NSError(domain: "CategoryService",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode CategoryResponse"])
                    completion(.failure(error))
                    return
                }
                
                completion(.success(response.categories))
                
            case .failure(let error):
                debugPrint("[Request] 节点分类请求失败：\(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

