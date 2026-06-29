// TC7 harness — wraps primary step JS in async IIFE, runs against closed-item fixture.
// Detects TDZ ReferenceError on `kind` access (or any other ReferenceError).
const context = {
  payload: { issue: { number: 1, state: 'closed', labels: [] } },
  repo: { owner: 'x', repo: 'y' }
};
const core = { info: (msg) => process.stderr.write('[core.info] ' + msg + '\n') };
const github = {
  rest: {
    issues: {
      listComments: async () => ({ data: [] }),
      createComment: async () => ({}),
      updateComment: async () => ({})
    }
  }
};
const SCRIPT_SOURCE = process.env.D076_TC7_SCRIPT || '';
// Wrap in async IIFE so `return` keyword is valid (top-level return is SyntaxError).
const wrapped = '(async () => {\n' + SCRIPT_SOURCE + '\n})()';
(async () => {
  try {
    await eval(wrapped);
    console.log('NO_REFERENCE_ERROR');
    process.exit(0);
  } catch (e) {
    if (e instanceof ReferenceError) {
      console.log('REFERENCE_ERROR: ' + e.message);
      process.exit(1);
    } else {
      console.log('OTHER_ERROR: ' + e.constructor.name + ': ' + e.message);
      process.exit(2);
    }
  }
})();
