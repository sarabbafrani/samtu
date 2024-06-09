<button onclick="copyToClipboard()">
  <img src="https://img.icons8.com/ios/24/000000/copy.png" alt="Copy Icon" style="vertical-align:middle">
  Copy Command
</button>

<script>
function copyToClipboard() {
  var copyText = document.getElementById("commandToCopy");
  copyText.select();
  copyText.setSelectionRange(0, 99999);
  document.execCommand("copy");
  alert("Copied the command: " + copyText.value);
}
</script>

<p>
  <input type="text" value="curl -sSL https://raw.githubusercontent.com/sarabbafrani/samtu/main/mtu.sh > mtu.sh && chmod +x mtu.sh && sudo ./mtu.sh" id="commandToCopy" style="position: absolute; left: -9999px;">
  <span style="font-family: monospace;">curl -sSL https://raw.githubusercontent.com/sarabbafrani/samtu/main/mtu.sh > mtu.sh && chmod +x mtu.sh && sudo ./mtu.sh</span>
</p>
