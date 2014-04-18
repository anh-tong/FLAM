% Second-kind integral equation on the unit square, Laplace single-layer.

function ie_square(n,occ,p,rank_or_tol,store,symm)

  % set default parameters
  if nargin < 1 || isempty(n)
    n = 128;
  end
  if nargin < 2 || isempty(occ)
    occ = 128;
  end
  if nargin < 3 || isempty(p)
    p = 64;
  end
  if nargin < 4 || isempty(rank_or_tol)
    rank_or_tol = 1e-9;
  end
  if nargin < 5 || isempty(store)
    store = 'a';
  end
  if nargin < 6 || isempty(symm)
    symm = 's';
  end

  % initialize
  [x1,x2] = ndgrid((1:n)/n);
  x = [x1(:) x2(:)]';
  N = size(x,2);
  theta = (1:p)*2*pi/p;
  proxy = 1.5*[cos(theta); sin(theta)];
  clear x1 x2

  % compute diagonal quadratures
  h = 1/n;
  intgrl = 4*dblquad(@(x,y)(-1/(2*pi)*log(sqrt(x.^2 + y.^2))),0,h/2,0,h/2);

  % compress matrix
  opts = struct('store',store,'symm',symm,'verb',1);
  F = ifmm(@Afun,x,x,occ,rank_or_tol,@pxyfun,opts);
  w = whos('F');
  fprintf([repmat('-',1,80) '\n'])
  fprintf('mem: %6.2f (MB)\n',w.bytes/1e6)

  % set up FFT multiplication
  a = reshape(Afun(1:N,1),n,n);
  B = zeros(2*n-1,2*n-1);
  B(  1:n  ,  1:n  ) = a;
  B(  1:n  ,n+1:end) = a( : ,2:n);
  B(n+1:end,  1:n  ) = a(2:n, : );
  B(n+1:end,n+1:end) = a(2:n,2:n);
  B(:,n+1:end) = flipdim(B(:,n+1:end),2);
  B(n+1:end,:) = flipdim(B(n+1:end,:),1);
  G = fft2(B);

  % test accuracy using randomized power method
  X = rand(N,1);
  X = X/norm(X);

  % NORM(A - F)/NORM(A)
  tic
  ifmm_mv(F,X,@Afun);
  t = toc;
  [e,niter] = snorm(N,@(x)(mv(x) - ifmm_mv(F,x,@Afun)),[],[],1);
  e = e/snorm(N,@mv,[],[],1);
  fprintf('mv: %10.4e / %4d / %10.4e (s)\n',e,niter,t)

  % run GMRES
  tic
  [Y,~,~,iter] = gmres(@(x)(ifmm_mv(F,x,@Afun)),X,[],1e-12,32);
  t = toc;
  e = norm(X - mv(Y))/norm(X);
  fprintf('gmres: %10.4e / %4d / %10.4e (s)\n',e,iter(2),t)

  % kernel function
  function K = Kfun(x,y)
    dx = bsxfun(@minus,x(1,:)',y(1,:));
    dy = bsxfun(@minus,x(2,:)',y(2,:));
    K = -1/(2*pi)*log(sqrt(dx.^2 + dy.^2));
  end

  % matrix entries
  function A = Afun(i,j)
    A = Kfun(x(:,i),x(:,j))/N;
    [I,J] = ndgrid(i,j);
    A(I == J) = 1 + intgrl;
  end

  % proxy function
  function K = pxyfun(rc,rx,cx,slf,nbr,l,ctr)
    pxy = bsxfun(@plus,proxy*l,ctr');
    if strcmp(rc,'r')
      K = Kfun(rx(:,slf),pxy);
    elseif strcmp(rc,'c')
      K = Kfun(pxy,cx(:,slf));
    end
  end

  % FFT multiplication
  function y = mv(x)
    y = ifft2(G.*fft2(reshape(x,n,n),2*n-1,2*n-1));
    y = reshape(y(1:n,1:n),N,1);
  end
end