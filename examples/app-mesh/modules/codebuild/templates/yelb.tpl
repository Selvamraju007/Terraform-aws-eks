apiVersion: v1
kind: Namespace
metadata:
  name: yelb
  labels:
    mesh: yelb-mesh
    appmesh.k8s.aws/sidecarInjectorWebhook: enabled
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: Mesh
metadata:
  name: yelb-mesh
spec:
  namespaceSelector:
    matchLabels:
      mesh: yelb-mesh
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  namespace: yelb
  name: yelb-db
spec:
  awsName: yelb-db-virtual-node
  podSelector:
    matchLabels:
      app: yelb-db
  listeners:
    - portMapping:
        port: 5432
        protocol: tcp
  serviceDiscovery:
    dns:
      hostname: >-
        yelb-db.yelb.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  namespace: yelb
  name: yelb-db
spec:
  awsName: yelb-db
  provider:
    virtualNode:
      virtualNodeRef:
        name: yelb-db
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  namespace: yelb
  name: redis-server
spec:
  awsName: redis-server-virtual-node
  podSelector:
    matchLabels:
      app: redis-server
  listeners:
    - portMapping:
        port: 6379
        protocol: tcp
  serviceDiscovery:
    dns:
      hostname: >-
        redis-server.yelb.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  namespace: yelb
  name: redis-server
spec:
  awsName: redis-server
  provider:
    virtualNode:
      virtualNodeRef:
        name: redis-server
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  namespace: yelb
  name: yelb-ui
spec:
  awsName: yelb-ui-virtual-node
  podSelector:
    matchLabels:
      app: yelb-ui
  listeners:
    - portMapping:
        port: 80
        protocol: http
  serviceDiscovery:
    dns:
      hostname: >-
        yelb-ui.yelb.svc.cluster.local
  backends:
    - virtualService:
       virtualServiceRef:
          name: yelb-appserver
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  namespace: yelb
  name: yelb-ui
spec:
  awsName: yelb-ui
  provider:
    virtualNode:
      virtualNodeRef:
        name: yelb-ui
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  namespace: yelb
  name: yelb-appserver
spec:
  awsName: yelb-appserver-virtual-node
  podSelector:
    matchLabels:
      app: yelb-appserver
  listeners:
    - portMapping:
        port: 4567
        protocol: http
  serviceDiscovery:
    dns:
      hostname: >-
        yelb-appserver.yelb.svc.cluster.local
  backends:
    - virtualService:
       virtualServiceRef:
          name: yelb-db
    - virtualService:
       virtualServiceRef:
          name: redis-server
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualRouter
metadata:
  namespace: yelb
  name: yelb-appserver
spec:
  awsName: yelb-appserver-virtual-router
  listeners:
    - portMapping:
        port: 4567
        protocol: http
  routes:
    - name: route-to-yelb-appserver
      httpRoute:
        match:
          prefix: /
        action:
          weightedTargets:
            - virtualNodeRef:
                name: yelb-appserver
              weight: 1
        retryPolicy:
            maxRetries: 2
            perRetryTimeout:
                unit: ms
                value: 2000
            httpRetryEvents:
                - server-error
                - client-error
                - gateway-error
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  namespace: yelb
  name: yelb-appserver
spec:
  awsName: yelb-appserver
  provider:
    virtualRouter:
        virtualRouterRef:
            name: yelb-appserver
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  namespace: yelb
  name: yelb-appserver-v2
spec:
  awsName: yelb-appserver-virtual-node-v2
  podSelector:
    matchLabels:
      app: yelb-appserver-v2
  listeners:
    - portMapping:
        port: 4567
        protocol: http
  serviceDiscovery:
    dns:
      hostname: >-
        yelb-appserver-v2.yelb.svc.cluster.local
  backends:
    - virtualService:
       virtualServiceRef:
          name: yelb-db
    - virtualService:
       virtualServiceRef:
          name: redis-server
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualRouter
metadata:
  namespace: yelb
  name: yelb-appserver
spec:
  awsName: yelb-appserver-virtual-router
  listeners:
    - portMapping:
        port: 4567
        protocol: http
  routes:
    - name: route-to-yelb-appserver
      httpRoute:
        match:
          prefix: /
        action:
          weightedTargets:
            - virtualNodeRef:
                name: yelb-appserver
              weight: 1
            - virtualNodeRef:
                name: yelb-appserver-v2
              weight: 1
        retryPolicy:
            maxRetries: 2
            perRetryTimeout:
                unit: ms
                value: 2000
            httpRetryEvents:
                - server-error
                - client-error
                - gateway-error
---
apiVersion: v1
kind: Service
metadata:
  namespace: yelb
  name: redis-server
  labels:
    app: redis-server
    tier: cache
spec:
  type: ClusterIP
  ports:
    - port: 6379
  selector:
    app: redis-server
    tier: cache
---
apiVersion: v1
kind: Service
metadata:
  namespace: yelb
  name: yelb-db
  labels:
    app: yelb-db
    tier: backenddb
spec:
  type: ClusterIP
  ports:
    - port: 5432
  selector:
    app: yelb-db
    tier: backenddb
---
apiVersion: v1
kind: Service
metadata:
  namespace: yelb
  name: yelb-appserver
  labels:
    app: yelb-appserver
    tier: middletier
spec:
  type: ClusterIP
  ports:
    - port: 4567
  selector:
    app: yelb-appserver
    tier: middletier
---
apiVersion: v1
kind: Service
metadata:
  namespace: yelb
  name: yelb-ui
  labels:
    app: yelb-ui
    tier: frontend
spec:
  type: NodePort
  ports:
    - port: 80
      protocol: TCP
  selector:
    app: yelb-ui
    tier: frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: yelb-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: yelb-ui
      tier: frontend
  template:
    metadata:
      labels:
        app: yelb-ui
        tier: frontend
    spec:
      containers:
        - name: yelb-ui
          image: mreferre/yelb-ui:0.7
          ports:
            - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: redis-server
spec:
  selector:
    matchLabels:
      app: redis-server
      tier: cache
  replicas: 1
  template:
    metadata:
      labels:
        app: redis-server
        tier: cache
    spec:
      containers:
        - name: redis-server
          image: redis:4.0.2
          ports:
            - containerPort: 6379
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: yelb-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: yelb-db
      tier: backenddb
  template:
    metadata:
      labels:
        app: yelb-db
        tier: backenddb
    spec:
      containers:
        - name: yelb-db
          image: mreferre/yelb-db:0.5
          ports:
            - containerPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: yelb-appserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: yelb-appserver
      tier: middletier
  template:
    metadata:
      labels:
        app: yelb-appserver
        tier: middletier
    spec:
      containers:
        - name: yelb-appserver
          image: mreferre/yelb-appserver:0.5
          ports:
            - containerPort: 4567
---
apiVersion: v1
kind: Service
metadata:
  namespace: yelb
  name: yelb-appserver-v2
  labels:
    app: yelb-appserver-v2
    tier: middletier
spec:
  type: ClusterIP
  ports:
    - port: 4567
  selector:
    app: yelb-appserver-v2
    tier: middletier
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: yelb
  name: yelb-appserver-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: yelb-appserver-v2
      tier: middletier
  template:
    metadata:
      labels:
        app: yelb-appserver-v2
        tier: middletier
    spec:
      containers:
        - name: yelb-appserver-v2
          image: ${ecr_uri}:v2
          ports:
            - containerPort: 4567