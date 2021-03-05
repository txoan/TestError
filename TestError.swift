import Foundation
import Combine

protocol Repository {
    func process() -> AnyPublisher<Void, RepositoryError>
}

protocol DataSource {
    func process() -> AnyPublisher<Void, Error>
}

enum NetworkDataError: Error {
    case client(code: Int, message: String)
    case unauthorized
}

enum StorageDataError: Error {
    case empty
}

enum CoreDataError: Error {
    case notFound
    case empty
}

struct NetworkDataSource: DataSource {
    func process() -> AnyPublisher<Void, Error> {
        Fail(error: NetworkDataError.client(code: 404, message: "not found")).eraseToAnyPublisher()
    }
}

struct LocalDataSource: DataSource {
    func process() -> AnyPublisher<Void, Error> {
        Fail(error: StorageDataError.empty).eraseToAnyPublisher()
    }
}
struct CoreDataSource: DataSource {
    func process() -> AnyPublisher<Void, Error> {
        Fail(error: CoreDataError.notFound).eraseToAnyPublisher()
    }
}
let fallbackMessage: String = "Ha ocurrido un error inesperado. Por favor, inténtelo de nuevo más tarde."
struct RepositoryImpl: Repository {
    let networkDataSource: DataSource
    let localDataSource: DataSource
    let coreDataSource: CoreDataSource

    func process() -> AnyPublisher<Void, RepositoryError> {
        if Bool.random() {
            return Fail(error: RepositoryError.notAvailable).eraseToAnyPublisher()
        }
        let options: [AnyPublisher<Void, Error>] = [localDataSource.process(), networkDataSource.process(), coreDataSource.process()]

        let publisher = options.randomElement()!
        return publisher.mapError { error -> RepositoryError in
            switch error {
            case is NetworkDataError:
                let value = (error as! NetworkDataError)
                switch value {
                    case .client(let code, let message):
                        if code == 401 || code == 403 {
                            return .notAuthorized
                        }else if code == 404 {
                            return .noData(message: message)
                        } else if code == 500 {
                            return .notAvailable
                        } else {
                            return .noFound
                        }
                    default : break
                }
                return .noData(message: fallbackMessage)
            case is StorageDataError:
                return .noFound
            case is CoreDataError:
                return .notAvailable
            default: return .notAvailable
            }
        }.eraseToAnyPublisher()
    }
}


enum RepositoryError: Error {
    case noData(message: String)
    case notAvailable
    case noFound
    case notAuthorized

}

var subscriptions = Set<AnyCancellable>()
let repository = RepositoryImpl(networkDataSource: NetworkDataSource(), localDataSource: LocalDataSource(), coreDataSource: CoreDataSource())
repository.process()
    .sink(receiveCompletion: { completion in
        switch completion {
            case .finished: break
            case let .failure(error): print(error)
        }
        }, receiveValue: { print($0) })
    .store(in: &subscriptions)

