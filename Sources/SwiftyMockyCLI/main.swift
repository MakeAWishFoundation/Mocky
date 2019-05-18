import Foundation
import Commander
import PathKit
import SwiftyMockyCLICore

let application = Application()

Message.swiftyMockyLabel("v\(application.version)")

Group() { main in

    main.command("setup", description: Messages.Setup.description) { (parser: ArgumentParser) in
        application.setup(project: parser.remainder.last)
    }

    main.command("migrate", description: Messages.Migrate.description) { (parser: ArgumentParser) in
        application.migrate(project: parser.remainder.last)
    }

    main.command("autoimport", description: Messages.Autoimport.description) { (parser: ArgumentParser) in
        application.autoimport(forMock: parser.remainder.last)
    }

    main.command("doctor", description: Messages.Doctor.description) { (parser: ArgumentParser) in
        application.doctor(project: parser.remainder.last)
    }

    main.command("generate",
                 Flag("disableCache", default: false, description: "Disables cache"),
                 Flag("verbose", default: false, description: "Additional output"),
                 description: Messages.Generate.description
    ) { (disableCache: Bool, verbose: Bool) in
        application.generate(disableCache: disableCache, verbose: verbose)
    }

    #if DEBUG
    main.command("encode") { (file: String, output: String) in
        application.encode(file: file, output: output)
    }
    #endif
}
.run()
