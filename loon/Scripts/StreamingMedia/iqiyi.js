let url = "https://www.iq.com/";
let headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
};

function getTimestamp() {
    const now = new Date();
    return `[${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}]`;
}

console.log(`${getTimestamp()} 🚀 开始发起 iQIYI 国际版解锁检测请求`);
console.log(`${getTimestamp()} 🌐 请求 URL: ${url}`);
console.log(`${getTimestamp()} 📋 请求 Headers: ${JSON.stringify(headers)}`);

$httpClient.get({ url: url, headers: headers }, function (error, response, body) {
    let result = {};

    if (error) {
        result.message = "iQIYI: 网络连接失败";
        console.log(`${getTimestamp()} ❌ iQIYI 检测结果 - ${result.message}`);
        console.log(`${getTimestamp()} 🔍 错误详情: ${error}`);
        $done({
            response: {
                status: 200,
                body: JSON.stringify(result),
                headers: { "Content-Type": "application/json" }
            }
        });
        return;
    }

    console.log(`${getTimestamp()} ✅ iQIYI 响应体获取成功`);
    console.log(`${getTimestamp()} 📊 响应状态码: ${response.status}`);
    console.log(`${getTimestamp()} 📄 响应头: ${JSON.stringify(response.headers)}`);

    if (body) {
        let regionMatch = body.match(/mod=([a-z]+)/i);
        if (regionMatch && regionMatch[1]) {
            let regionCode = regionMatch[1].toUpperCase();
            if (regionCode === "NTW") regionCode = "TW";

            result.message = `iQIYI: 已解锁 ✅ (地区: ${regionCode})`;
            console.log(`${getTimestamp()} 🌍 iQIYI 检测结果 - ${result.message}`);
            console.log(`${getTimestamp()} 🔎 检测到的地区代码: ${regionCode}`);
        } else {
            result.message = "iQIYI: 未解锁 ❌ (地区信息缺失)";
            console.log(`${getTimestamp()} ❌ iQIYI 检测结果 - ${result.message}`);
            console.log(`${getTimestamp()} 🔍 响应体中未找到地区信息`);
        }
    } else {
        result.message = "iQIYI: 检测失败，无法获取响应";
        console.log(`${getTimestamp()} ❌ iQIYI 检测结果 - ${result.message}`);
        console.log(`${getTimestamp()} 🔍 响应体为空`);
    }

    $done({
        response: {
            status: 200,
            body: JSON.stringify(result),
            headers: { "Content-Type": "application/json" }
        }
    });
});
