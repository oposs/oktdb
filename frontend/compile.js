qx.Class.define("callbackery.compile.CompilerApi", {
    extend: qx.tool.cli.api.CompilerApi,
    members: {
        async load() {
            let config = await this.base(arguments);
            if (!config.libraries) {
                config.libraries = ['.'];
            }
            let cbr = process.env.CALLBACKERY_QX;
            if (cbr) {
                ["callbackery"].forEach(dir => {
                    console.log(`pushing ${cbr}/${dir}`);
                    config.libraries.push(cbr+"/"+dir);

                });
            }
            return config;
        }
    }
});


module.exports = {
    CompilerApi: callbackery.compile.CompilerApi
};
